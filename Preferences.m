#import <Preferences/Preferences.h>

#import "libactivator.h"

static LAActivator *activator;

@interface ActivatorTableViewController : PSViewController<UITableViewDataSource, UITableViewDelegate> {
@private
	UITableView *_tableView;
}

@end

@implementation ActivatorTableViewController

+ (void)load
{
	activator = [LAActivator sharedInstance];
}

- (id)initForContentSize:(CGSize)size
{
	if ((self = [super initForContentSize:size])) {
		CGRect frame;
		frame.origin = CGPointZero;
		frame.size = size;
		_tableView = [[UITableView alloc] initWithFrame:frame style:UITableViewStyleGrouped];
		[_tableView setRowHeight:60.0f];
		[_tableView setDataSource:self];
		[_tableView setDelegate:self];
	}
	return self;
}

- (void)dealloc
{
	[_tableView setDelegate:nil];
	[_tableView setDataSource:nil];
	[_tableView release];
	[super dealloc];
}

- (UIView *)view
{
	return _tableView;
}

- (UITableView *)tableView
{
	return _tableView;
}

- (CGSize)contentSize
{
	return [_tableView frame].size;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return [tableView dequeueReusableCellWithIdentifier:@"cell"] ?: [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"] autorelease];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)pushController:(id<PSBaseView>)controller
{
	//[[self parentController] pushController:controller];
	[super pushController:controller];
	[controller setParentController:self];
}

@end

@interface ActivatorEventViewController : ActivatorTableViewController {
@private
	NSArray *_modes;
	NSString *_eventName;
	NSArray *_listeners;
}
@end

@implementation ActivatorEventViewController

- (id)initForContentSize:(CGSize)contentSize withModes:(NSArray *)modes eventName:(NSString *)eventName
{
	if ((self = [super initForContentSize:contentSize])) {
		NSMutableArray *availableModes = [NSMutableArray array];
		for (NSString *mode in modes)
			if ([activator eventWithName:eventName isCompatibleWithMode:mode])
				[availableModes addObject:mode];
		_modes = [availableModes copy];
		NSMutableArray *listeners = [NSMutableArray array];
		for (NSString *listenerName in [activator availableListenerNames])
			for (NSString *mode in _modes)
				if ([activator listenerWithName:listenerName isCompatibleWithMode:mode]) {
					[listeners addObject:listenerName];
					break;
				}
		_listeners = [listeners copy];
		_eventName = [eventName copy];
	}
	return self;
}

- (void)dealloc
{
	[_listeners release];
	[_eventName release];
	[_modes release];
	[super dealloc];
}

- (void)showLastEventMessageForListener:(NSString *)listenerName
{
	UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"Can't deactivate\nremaining event" message:[@"At least one event must be\nassigned to " stringByAppendingString:[activator localizedTitleForListenerName:listenerName]] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[av show];
	[av release];
}

- (BOOL)allowedToUnassignEventsFromListener:(NSString *)listenerName
{
	if (![activator listenerWithNameRequiresAssignment:listenerName])
		return YES;
	NSInteger assignedCount = [[activator eventsAssignedToListenerWithName:listenerName] count];
	for (NSString *mode in _modes)
		if ([[activator assignedListenerNameForEvent:[LAEvent eventWithName:_eventName mode:mode]] isEqual:listenerName])
			assignedCount--;
	return assignedCount > 0;
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	return [_listeners count];
}

- (NSInteger)countOfModesAssignedToListener:(NSString *)name
{
	NSInteger result = 0;
	for (NSString *mode in _modes) {
		NSString *assignedName = [activator assignedListenerNameForEvent:[LAEvent eventWithName:_eventName mode:mode]];
		result += [assignedName isEqual:name];
	}
	return result;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
	NSString *listenerName = [_listeners objectAtIndex:[indexPath row]];
	[[cell textLabel] setText:[activator localizedTitleForListenerName:listenerName]];
	UITableViewCellAccessoryType accessory = 
		[self countOfModesAssignedToListener:listenerName] ?
		UITableViewCellAccessoryCheckmark :
		UITableViewCellAccessoryNone;
	[[cell detailTextLabel] setText:[activator localizedDescriptionForListenerName:listenerName]];
	[[cell imageView] setImage:[activator smallIconForListenerName:listenerName]];
	[cell setAccessoryType:accessory];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];
	UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
	NSString *listenerName = [_listeners objectAtIndex:[indexPath row]];
	NSUInteger compatibleModeCount = 0;
	for (NSString *mode in _modes)
		if ([activator listenerWithName:listenerName isCompatibleWithMode:mode])
			compatibleModeCount++;
	BOOL allAssigned = [self countOfModesAssignedToListener:listenerName] >= compatibleModeCount;
	if (allAssigned) {
		if (![self allowedToUnassignEventsFromListener:listenerName]) {
			[self showLastEventMessageForListener:listenerName];
			return;
		}
		[cell setAccessoryType:UITableViewCellAccessoryNone];
		for (NSString *mode in _modes)
			[activator unassignEvent:[LAEvent eventWithName:_eventName mode:mode]];
	} else {
		for (NSString *mode in _modes) {
			NSString *otherListener = [activator assignedListenerNameForEvent:[LAEvent eventWithName:_eventName mode:mode]];
			if (otherListener && ![otherListener isEqual:listenerName]) {
				if (![self allowedToUnassignEventsFromListener:otherListener]) {
					[self showLastEventMessageForListener:otherListener];
					return;
				}
			}
		}
		for (UITableViewCell *otherCell in [tableView visibleCells])
			[otherCell setAccessoryType:UITableViewCellAccessoryNone];
		[cell setAccessoryType:UITableViewCellAccessoryCheckmark];
		for (NSString *mode in _modes)
			[activator assignEvent:[LAEvent eventWithName:_eventName mode:mode] toListenerWithName:listenerName];
	}
}

- (NSString *)navigationTitle
{
	return [activator localizedTitleForEventName:_eventName];
}

@end

@interface ActivatorModeViewController : ActivatorTableViewController {
@private
	NSString *_eventMode;
	NSMutableDictionary *_events;
}
@end

@implementation ActivatorModeViewController

- (id)initForContentSize:(CGSize)contentSize withMode:(NSString *)mode
{
	if ((self = [super initForContentSize:contentSize])) {
		_eventMode = [mode copy];
		BOOL showHidden = [[[NSDictionary dictionaryWithContentsOfFile:[activator settingsFilePath]] objectForKey:@"LAShowHiddenEvents"] boolValue];
		_events = [[NSMutableDictionary alloc] init];
		for (NSString *eventName in [activator availableEventNames]) {
			if ([activator eventWithName:eventName isCompatibleWithMode:mode]) {
				if (!([activator eventWithNameIsHidden:eventName] || showHidden)) {
					NSString *key = [activator localizedGroupForEventName:eventName] ?: @"";
					NSMutableArray *groupList = [_events objectForKey:key];
					if (!groupList) {
						groupList = [NSMutableArray array];
						[_events setObject:groupList forKey:key];
					}
					[groupList addObject:eventName];
				}
			}
		}
	}
	return self;
}

- (void)dealloc
{
	[_events release];
	[_eventMode release];
	[super dealloc];
}

- (NSMutableArray *)groupAtIndex:(NSInteger)index
{
	return [_events objectForKey:[[_events allKeys] objectAtIndex:index]];
}

- (NSString *)eventNameForIndexPath:(NSIndexPath *)indexPath
{
	return [[self groupAtIndex:[indexPath section]] objectAtIndex:[indexPath row]];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return [[_events allKeys] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	return [[_events allKeys] objectAtIndex:section];
}

- (NSInteger)tableView:(UITableView *)table numberOfRowsInSection:(NSInteger)section
{
	return [[self groupAtIndex:section] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
	NSInteger row = [indexPath row];
	NSString *eventName = [self eventNameForIndexPath:indexPath];
	CGFloat alpha = [activator eventWithNameIsHidden:eventName] ? 0.66f : 1.0f;
	UILabel *label = [cell textLabel];
	[label setText:[activator localizedTitleForEventName:eventName]];
	[label setAlpha:alpha];
	UILabel *detailLabel = [cell detailTextLabel];
	[detailLabel setText:[activator localizedDescriptionForEventName:eventName]];
	[detailLabel setAlpha:alpha];
	[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
	return cell;	
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];
	NSArray *modes = _eventMode ? [NSArray arrayWithObject:_eventMode] : [activator availableEventModes];
	PSViewController *vc = [[ActivatorEventViewController alloc] initForContentSize:[self contentSize] withModes:modes eventName:[self eventNameForIndexPath:indexPath]];
	[self pushController:vc];
	[vc release];
}

- (NSString *)navigationTitle
{
	return [activator localizedTitleForEventMode:_eventMode];
}

@end

@interface ActivatorSettingsController : ActivatorTableViewController {
@private
	NSString *_title;
	LAListenerSettingsViewController *_viewController;
	CGSize _size;
}
@end

@implementation ActivatorSettingsController

- (void)dealloc
{
	[_viewController release];
	[_title release];
	[super dealloc];
}

- (void)viewWillBecomeVisible:(void *)source
{
	// Load LAListenerSettingsViewController if activatorListener is set in the specifier
	[_viewController release];
	_viewController = nil;
	[_title release];
	_title = nil;
	if (source) {
		PSSpecifier *specifier = (PSSpecifier *)source;
		NSString *listenerName = [specifier propertyForKey:@"activatorListener"];
		if ([listenerName length]) {
			NSLog(@"libactivator: Configuring %@", listenerName);
			_viewController = [[LAListenerSettingsViewController alloc] init];
			[_viewController setListenerName:listenerName];
			_title = [[specifier propertyForKey:@"activatorTitle"]?:[specifier name] copy];
		}
	}
	[super viewWillBecomeVisible:source];
}

- (UIView *)view
{
	// Swap out for view controller if set
	UIView *view = [super view];
	if (_viewController) {
		UIView *replacement = [_viewController view];
		[replacement setFrame:[view frame]];
		view = replacement;
	}
	return view;
}

- (NSString *)navigationTitle
{
	if ([_title length])
		return _title;
	else
		return @"Activator Settings";
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return (section == 0) ? 1 : [[activator availableEventModes] count];
}

- (NSString *)eventModeForIndexPath:(NSIndexPath *)indexPath
{
	if ([indexPath section] == 0)
		return nil;
	return [[activator availableEventModes] objectAtIndex:[indexPath row]];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{	
	UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
	NSString *eventMode = [self eventModeForIndexPath:indexPath];
	[[cell textLabel] setText:[activator localizedTitleForEventMode:eventMode]];
	[[cell detailTextLabel] setText:[activator localizedDescriptionForEventMode:eventMode]];
	[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[super tableView:tableView didSelectRowAtIndexPath:indexPath];
	PSViewController *vc = [[ActivatorModeViewController alloc] initForContentSize:[self contentSize] withMode:[self eventModeForIndexPath:indexPath]];
	[self pushController:vc];
	[vc release];
}

@end
