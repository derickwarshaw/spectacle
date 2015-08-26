#import <Sparkle/Sparkle.h>

#import "SpectacleAppDelegate.h"
#import "SpectacleConstants.h"
#import "SpectaclePreferencesController.h"
#import "SpectacleShortcutManager.h"
#import "SpectacleShortcutTranslator.h"
#import "SpectacleShortcutUserDefaultsStorage.h"
#import "SpectacleUtilities.h"
#import "SpectacleWindowPositionManager.h"

@interface SpectacleAppDelegate ()

@property (nonatomic) NSDictionary *shortcutMenuItems;
@property (nonatomic) NSStatusItem *statusItem;
@property (nonatomic) id<SpectacleShortcutStorageProtocol> shortcutStorage;
@property (nonatomic) SpectacleShortcutManager *shortcutManager;
@property (nonatomic) SpectacleWindowPositionManager *windowPositionManager;
@property (nonatomic) SpectaclePreferencesController *preferencesController;
@property (nonatomic) NSTimer *disableShortcutsForAnHourTimer;
@property (nonatomic) NSSet *blacklistedApplications;
@property (nonatomic) NSMutableSet *disabledApplications;

@end

#pragma mark -

@implementation SpectacleAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
  NSNotificationCenter *notificationCenter = NSNotificationCenter.defaultCenter;

  [notificationCenter addObserver:self
                         selector:@selector(enableStatusItem)
                             name:kStatusItemEnabledNotification
                           object:nil];

  [notificationCenter addObserver:self
                         selector:@selector(disableStatusItem)
                             name:kStatusItemDisabledNotification
                           object:nil];

  [notificationCenter addObserver:self
                         selector:@selector(updateShortcutMenuItems)
                             name:kShortcutChangedNotification
                           object:nil];

  [notificationCenter addObserver:self
                         selector:@selector(updateShortcutMenuItems)
                             name:kRestoreDefaultShortcutsNotification
                           object:nil];

  [notificationCenter addObserver:self
                         selector:@selector(menuDidSendAction:)
                             name:NSMenuDidSendActionNotification
                           object:nil];

  [SpectacleUtilities registerDefaultsForBundle:NSBundle.mainBundle];

  self.shortcutMenuItems = @{kWindowActionMoveToCenter: _moveToCenterShortcutMenuItem,
                             kWindowActionMoveToFullscreen: _moveToFullscreenShortcutMenuItem,
                             kWindowActionMoveToLeftHalf: _moveToLeftShortcutMenuItem,
                             kWindowActionMoveToRightHalf: _moveToRightShortcutMenuItem,
                             kWindowActionMoveToTopHalf: _moveToTopShortcutMenuItem,
                             kWindowActionMoveToBottomHalf: _moveToBottomShortcutMenuItem,
                             kWindowActionMoveToUpperLeft: _moveToUpperLeftShortcutMenuItem,
                             kWindowActionMoveToLowerLeft: _moveToLowerLeftShortcutMenuItem,
                             kWindowActionMoveToUpperRight: _moveToUpperRightShortcutMenuItem,
                             kWindowActionMoveToLowerRight: _moveToLowerRightShortcutMenuItem,
                             kWindowActionMoveToNextDisplay: _moveToNextDisplayShortcutMenuItem,
                             kWindowActionMoveToPreviousDisplay: _moveToPreviousDisplayShortcutMenuItem,
                             kWindowActionMoveToNextThird: _moveToNextThirdShortcutMenuItem,
                             kWindowActionMoveToPreviousThird: _moveToPreviousThirdShortcutMenuItem,
                             kWindowActionMakeLarger: _makeLargerShortcutMenuItem,
                             kWindowActionMakeSmaller: _makeSmallerShortcutMenuItem,
                             kWindowActionUndoLastMove: _undoLastMoveShortcutMenuItem,
                             kWindowActionRedoLastMove: _redoLastMoveShortcutMenuItem};

  self.shortcutStorage = [SpectacleShortcutUserDefaultsStorage new];
  self.shortcutManager = [[SpectacleShortcutManager alloc] initWithShortcutStorage:self.shortcutStorage];

  NSString *blacklistedApplicationsPath = [NSBundle.mainBundle pathForResource:kBlacklistedApplicationsPropertyListFile
                                                                        ofType:kPropertyListFileExtension];

  self.blacklistedApplications = [NSSet setWithArray:[NSArray arrayWithContentsOfFile:blacklistedApplicationsPath]];

  self.windowPositionManager = [[SpectacleWindowPositionManager alloc] initWithBlacklistedApplications:self.blacklistedApplications];

  NSUserDefaults *userDefaults = NSUserDefaults.standardUserDefaults;

  NSArray *disabledApplicationsArray = [userDefaults objectForKey:kDisabledApplicationsPreference];

  self.disabledApplications = [NSMutableSet setWithArray:disabledApplicationsArray];

  self.preferencesController = [[SpectaclePreferencesController alloc] initWithShortcutManager:self.shortcutManager
                                                                         windowPositionManager:self.windowPositionManager
                                                                               shortcutStorage:self.shortcutStorage
                                                                          disabledApplications:self.disabledApplications];

  [self registerShortcuts];

  BOOL automaticallyChecksForUpdates = [userDefaults boolForKey:kAutomaticUpdateCheckEnabledPreference];
  BOOL statusItemEnabled = [userDefaults boolForKey:kStatusItemEnabledPreference];

  if (statusItemEnabled) {
    [self enableStatusItem];
  }

  [SUUpdater.sharedUpdater setAutomaticallyChecksForUpdates:automaticallyChecksForUpdates];

  [self updateShortcutMenuItems];

  if (!AXIsProcessTrustedWithOptions(NULL)) {
    [[NSApplication sharedApplication] runModalForWindow:self.accessiblityAccessDialogWindow];
  }
}

#pragma mark -

- (BOOL)applicationShouldHandleReopen:(NSApplication *)application hasVisibleWindows:(BOOL)visibleWindows
{
  [self showPreferencesWindow:self];

  return YES;
}

#pragma mark -

- (IBAction)showPreferencesWindow:(id)sender
{
  [self.preferencesController showWindow:sender];
}

#pragma mark -

- (IBAction)moveFrontMostWindowToFullscreen:(id)sender
{
  [self.windowPositionManager moveFrontMostWindowWithWindowAction:SpectacleWindowActionFullscreen
                                             disabledApplications:self.disabledApplications];
}

- (IBAction)moveFrontMostWindowToCenter:(id)sender
{
  [self.windowPositionManager moveFrontMostWindowWithWindowAction:SpectacleWindowActionCenter
                                             disabledApplications:self.disabledApplications];
}

#pragma mark -

- (IBAction)moveFrontMostWindowToLeftHalf:(id)sender
{
  [self.windowPositionManager moveFrontMostWindowWithWindowAction:SpectacleWindowActionLeftHalf
                                             disabledApplications:self.disabledApplications];
}

- (IBAction)moveFrontMostWindowToRightHalf:(id)sender
{
  [self.windowPositionManager moveFrontMostWindowWithWindowAction:SpectacleWindowActionRightHalf
                                             disabledApplications:self.disabledApplications];
}

- (IBAction)moveFrontMostWindowToTopHalf:(id)sender
{
  [self.windowPositionManager moveFrontMostWindowWithWindowAction:SpectacleWindowActionTopHalf
                                             disabledApplications:self.disabledApplications];
}

- (IBAction)moveFrontMostWindowToBottomHalf:(id)sender
{
  [self.windowPositionManager moveFrontMostWindowWithWindowAction:SpectacleWindowActionBottomHalf
                                             disabledApplications:self.disabledApplications];
}

#pragma mark -

- (IBAction)moveFrontMostWindowToUpperLeft:(id)sender
{
  [self.windowPositionManager moveFrontMostWindowWithWindowAction:SpectacleWindowActionUpperLeft
                                             disabledApplications:self.disabledApplications];
}

- (IBAction)moveFrontMostWindowToLowerLeft:(id)sender
{
  [self.windowPositionManager moveFrontMostWindowWithWindowAction:SpectacleWindowActionLowerLeft
                                             disabledApplications:self.disabledApplications];
}

#pragma mark -

- (IBAction)moveFrontMostWindowToUpperRight:(id)sender
{
  [self.windowPositionManager moveFrontMostWindowWithWindowAction:SpectacleWindowActionUpperRight
                                             disabledApplications:self.disabledApplications];
}

- (IBAction)moveFrontMostWindowToLowerRight:(id)sender
{
  [self.windowPositionManager moveFrontMostWindowWithWindowAction:SpectacleWindowActionLowerRight
                                             disabledApplications:self.disabledApplications];
}

#pragma mark -

- (IBAction)moveFrontMostWindowToNextDisplay:(id)sender
{
  [self.windowPositionManager moveFrontMostWindowWithWindowAction:SpectacleWindowActionNextDisplay
                                             disabledApplications:self.disabledApplications];
}

- (IBAction)moveFrontMostWindowToPreviousDisplay:(id)sender
{
  [self.windowPositionManager moveFrontMostWindowWithWindowAction:SpectacleWindowActionPreviousDisplay
                                             disabledApplications:self.disabledApplications];
}

#pragma mark -

- (IBAction)moveFrontMostWindowToNextThird:(id)sender
{
  [self.windowPositionManager moveFrontMostWindowWithWindowAction:SpectacleWindowActionNextThird
                                             disabledApplications:self.disabledApplications];
}

- (IBAction)moveFrontMostWindowToPreviousThird:(id)sender
{
  [self.windowPositionManager moveFrontMostWindowWithWindowAction:SpectacleWindowActionPreviousThird
                                             disabledApplications:self.disabledApplications];
}

#pragma mark -

- (IBAction)makeFrontMostWindowLarger:(id)sender
{
  [self.windowPositionManager moveFrontMostWindowWithWindowAction:SpectacleWindowActionLarger
                                             disabledApplications:self.disabledApplications];
}

- (IBAction)makeFrontMostWindowSmaller:(id)sender
{
  [self.windowPositionManager moveFrontMostWindowWithWindowAction:SpectacleWindowActionSmaller
                                             disabledApplications:self.disabledApplications];
}

#pragma mark -

- (IBAction)undoLastWindowAction:(id)sender
{
  [self.windowPositionManager undoLastWindowAction];
}

- (IBAction)redoLastWindowAction:(id)sender
{
  [self.windowPositionManager redoLastWindowAction];
}

#pragma mark -

- (IBAction)disableOrEnableShortcutsForAnHour:(id)sender
{
  NSInteger newMenuItemState = NSMixedState;

  switch (self.disableShortcutsForAnHourMenuItem.state) {
    case NSOnState:
      [self.shortcutManager enableShortcuts];

      [self.disableShortcutsForAnHourTimer invalidate];

      newMenuItemState = NSOffState;
      break;
    case NSOffState:
      [self.shortcutManager disableShortcuts];

      SEL selector = @selector(disableOrEnableShortcutsForAnHour:);

      self.disableShortcutsForAnHourTimer = [NSTimer scheduledTimerWithTimeInterval:3600
                                                                             target:self
                                                                           selector:selector
                                                                           userInfo:nil
                                                                            repeats:NO];

      newMenuItemState = NSOnState;

      break;
    default:
      break;
  }

  self.disableShortcutsForAnHourMenuItem.state = newMenuItemState;
}

- (IBAction)disableOrEnableShortcutsForApplication:(id)sender
{
  NSString *frontmostApplicationBundleIdentifier = NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier;
  NSUserDefaults *userDefaults = NSUserDefaults.standardUserDefaults;

  if ([self.disabledApplications containsObject:frontmostApplicationBundleIdentifier]) {
    [self.disabledApplications removeObject:frontmostApplicationBundleIdentifier];

    self.disableShortcutsForApplicationMenuItem.state = NSOffState;
  } else {
    [self.disabledApplications addObject:frontmostApplicationBundleIdentifier];

    self.disableShortcutsForApplicationMenuItem.state = NSOnState;
  }

  [userDefaults setObject:[self.disabledApplications allObjects] forKey:kDisabledApplicationsPreference];
}

#pragma mark -

- (IBAction)openSystemPreferences:(id)sender
{
  NSURL *preferencePaneURL = [NSURL fileURLWithPath:[SpectacleUtilities pathForPreferencePaneNamed:kSecurityPreferencePaneName]];
  NSBundle *applicationBundle = NSBundle.mainBundle;
  NSURL *scriptURL = [applicationBundle URLForResource:kSecurityAndPrivacyPreferencesScriptName
                                         withExtension:kAppleScriptFileExtension];

  [NSApplication.sharedApplication stopModal];

  [self.accessiblityAccessDialogWindow orderOut:self];

  if (![[[NSAppleScript alloc] initWithContentsOfURL:scriptURL error:nil] executeAndReturnError:nil]) {
    [NSWorkspace.sharedWorkspace openURL:preferencePaneURL];
  }
}

#pragma mark -

- (void)registerShortcuts
{
  NSArray *shortcuts = [self.shortcutStorage loadShortcutsWithAction:^(SpectacleShortcut *shortcut) {
    SpectacleWindowAction windowAction = [self.windowPositionManager windowActionForShortcut:shortcut];

    [self.windowPositionManager moveFrontMostWindowWithWindowAction:windowAction
                                               disabledApplications:self.disabledApplications];
  }];

  [self.shortcutManager registerShortcuts:shortcuts];
}

#pragma mark -

- (void)enableStatusItem
{
  self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];

  NSImage *statusImage = [NSBundle.mainBundle imageForResource:kStatusItemIcon];

  [statusImage setTemplate:YES];

  self.statusItem.highlightMode = YES;
  self.statusItem.image = statusImage;
  self.statusItem.menu = self.statusItemMenu;
  self.statusItem.toolTip = [@"Spectacle " stringByAppendingString:SpectacleUtilities.applicationVersion];
}

- (void)disableStatusItem
{
  [NSStatusBar.systemStatusBar removeStatusItem:self.statusItem];
}

#pragma mark -

- (void)updateShortcutMenuItems
{
  SpectacleShortcutTranslator *shortcutTranslator = SpectacleShortcutTranslator.sharedTranslator;

  for (NSString *shortcutName in self.shortcutMenuItems.allKeys) {
    NSMenuItem *shortcutMenuItem = self.shortcutMenuItems[shortcutName];
    SpectacleShortcut *shortcut = [self.shortcutManager registeredShortcutForName:shortcutName];

    if (shortcut) {
      shortcutMenuItem.keyEquivalent = [[shortcutTranslator translateKeyCode:shortcut.shortcutCode] lowercaseString];
      shortcutMenuItem.keyEquivalentModifierMask = [SpectacleShortcutTranslator convertModifiersToCocoaIfNecessary:shortcut.shortcutModifiers];
    } else {
      shortcutMenuItem.keyEquivalent = @"";
      shortcutMenuItem.keyEquivalentModifierMask = 0;
    }
  }
}

#pragma mark -

- (void)menuWillOpen:(NSMenu *)menu
{
  NSString *frontmostApplicationLocalizedName = NSWorkspace.sharedWorkspace.frontmostApplication.localizedName;
  NSString *frontmostApplicationBundleIdentifier = NSWorkspace.sharedWorkspace.frontmostApplication.bundleIdentifier;

  self.disableShortcutsForApplicationMenuItem.hidden = NO;

  if (!frontmostApplicationLocalizedName || [self.blacklistedApplications containsObject:frontmostApplicationBundleIdentifier]) {
    self.disableShortcutsForApplicationMenuItem.hidden = YES;
  } else {
    self.disableShortcutsForApplicationMenuItem.title = [@"for " stringByAppendingString:frontmostApplicationLocalizedName];
  }

  if ([self.disabledApplications containsObject:frontmostApplicationBundleIdentifier]) {
    self.disableShortcutsForApplicationMenuItem.state = NSOnState;
  } else {
    self.disableShortcutsForApplicationMenuItem.state = NSOffState;
  }
}

- (void)menuDidSendAction:(NSNotification *)notification
{
  NSMenuItem *menuItem = (notification.userInfo)[@"MenuItem"];

  if (menuItem.tag == kMenuItemActivateIgnoringOtherApps) {
    [NSApplication.sharedApplication activateIgnoringOtherApps:YES];
  }
}

@end
