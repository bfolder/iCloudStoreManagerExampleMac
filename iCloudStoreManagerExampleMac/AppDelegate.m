//
//  AppDelegate.m
//  iCloudStoreManagerExampleMac
//
//  Created by Heiko Dreyer on 21.06.12.
//  Copyright (c) 2012 boxedfolder.com. All rights reserved.
//

#import "AppDelegate.h"
#import "User.h"
#import "Event.h"

@implementation AppDelegate

@synthesize window = _window;
@synthesize persistentStoreCoordinator = __persistentStoreCoordinator;
@synthesize managedObjectModel = __managedObjectModel;
@synthesize managedObjectContext = __managedObjectContext;
@synthesize ubiquityStoreManager = _ubiquityStoreManager;
@synthesize iCloudButton = _iCloudButton;
@synthesize removeButton = _removeButton;
@synthesize tableView = _tableView;
@synthesize events = _events;
@synthesize containerWindowController = _containerWindowController;

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - Init & Window related 

-(void)applicationDidFinishLaunching: (NSNotification *)notification
{
    // STEP 1 - Initialize the UbiquityStoreManager
	_ubiquityStoreManager = [[UbiquityStoreManager alloc] initWithManagedObjectModel: [self managedObjectModel] 
                                                                       localStoreURL: [self storeURL] 
                                                                 containerIdentifier: nil 
                                                              additionalStoreOptions: nil];
	// STEP 2a  - Setup the delegate
	_ubiquityStoreManager.delegate = self;
	
	// For test purposes only. NOT FOR USE IN PRODUCTION
	_ubiquityStoreManager.hardResetEnabled = YES;
    
    // STEP 2b - Check availability
    [_ubiquityStoreManager checkiCloudStatus];
    
	// Observe the app delegate telling us when it's finished asynchronously setting up the persistent store
    [[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(reloadData:)
												 name: RefetchAllDatabaseDataNotificationKey
											   object: _ubiquityStoreManager];
    
    
    [[NSNotificationCenter defaultCenter] addObserver: self
											 selector: @selector(refreshViews:)
												 name: RefreshAllViewsNotificationKey
											   object: _ubiquityStoreManager];
    
    // Fetch Data
    [self fetchData];
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)applicationWillBecomeActive: (NSNotification *)notification
{
	// STEP 5c - Display current state of the UbiquityStoreManager
    [_iCloudButton setState: _ubiquityStoreManager.iCloudEnabled];
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(NSApplicationTerminateReply)applicationShouldTerminate: (NSApplication *)sender
{
    // Save changes in the application's managed object context before the application terminates.
    if(!__managedObjectContext)
        return NSTerminateNow;
    
    if(![[self managedObjectContext] commitEditing]) 
    {
        NSLog(@"%@:%@ unable to commit editing to terminate", [self class], NSStringFromSelector(_cmd));
        return NSTerminateCancel;
    }
    
    if(![[self managedObjectContext] hasChanges])
        return NSTerminateNow;
    
    NSError *error = nil;
    if(![[self managedObjectContext] save: &error]) 
    {
        
        // Customize this code block to include application-specific recovery steps.              
        BOOL result = [sender presentError: error];
        if(result)
            return NSTerminateCancel;
        
        NSString *question = NSLocalizedString(@"Could not save changes while quitting. Quit anyway?", @"Quit without saves error question message");
        NSString *info = NSLocalizedString(@"Quitting now will lose any changes you have made since the last successful save", @"Quit without saves error question info");
        NSString *quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
        NSString *cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText: question];
        [alert setInformativeText: info];
        [alert addButtonWithTitle: quitButton];
        [alert addButtonWithTitle: cancelButton];
        
        NSInteger answer = [alert runModal];
        
        if(answer == NSAlertAlternateReturn)
            return NSTerminateCancel;
    }
    
    return NSTerminateNow;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)applicationWillTerminate: (NSNotification *)notification
{
    [[NSNotificationCenter defaultCenter] removeObserver: self 
                                                    name: RefetchAllDatabaseDataNotificationKey
                                                  object: _ubiquityStoreManager];
    
    [[NSNotificationCenter defaultCenter] removeObserver: self 
                                                    name: RefreshAllViewsNotificationKey
                                                  object: _ubiquityStoreManager];
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(NSUndoManager *)windowWillReturnUndoManager: (NSWindow *)window
{
    return [[self managedObjectContext] undoManager];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - Actions

-(void)add: (id)sender
{
    NSManagedObjectContext *context = self.managedObjectContext;
	User *user = [[self primaryUser] userInContext: context];
    
	[context performBlockAndWait: ^{
		NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName: @"Event" inManagedObjectContext: context];
		
		// If appropriate, configure the new managed object.
		// Normally you should use accessor methods, but using KVC here avoids the need to add a custom class to the template.
		[newManagedObject setValue: [NSDate date] forKey: @"timeStamp"];
		[newManagedObject setValue: user forKey: @"user"];
		
		// Save the context.
        [self saveContext];
        
        [_events insertObject: newManagedObject atIndex: 0];
        [self.tableView reloadData];
	}];
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)remove: (id)sender
{
    NSManagedObjectContext *context = [self managedObjectContext];
    
    [context performBlockAndWait: ^{
        
        NSMutableSet *objectsToDelete = [NSMutableSet setWithCapacity: self.tableView.selectedRowIndexes.count];
        [self.tableView.selectedRowIndexes enumerateIndexesUsingBlock: ^(NSUInteger idx, BOOL *stop){
            NSManagedObject *managedObject = [_events objectAtIndex: idx];
            [objectsToDelete addObject: managedObject];
        }];
        
        for(NSManagedObject *obj in objectsToDelete) 
        {
            [context deleteObject: obj];
            [_events removeObject: obj];
        }
        
		// Save the context.
        [self saveContext];
        [self.tableView reloadData];
    }];
    
    [sender setEnabled: NO];
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)clear: (id)sender
{
	// STEP 6 - UbiquityStoreManager hard reset. FOR TESTING ONLY! Do not expose to the end user!
    [_ubiquityStoreManager resetiCloudAlert];
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)useiCloud: (id)sender
{
	// STEP 5a - Set the state of the UbiquityStoreManager to reflect the current UI
    BOOL on = ((NSButton *)sender).state;
    [_ubiquityStoreManager useiCloudStore: on alertUser: YES];
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)viewContainer: (id)sender
{
    if(!_containerWindowController)
    {
        _containerWindowController = [[ContainerWindowController alloc] initWithWindowNibName: @"ContainerWindow"];
        _containerWindowController.ubiquityStoreManager = _ubiquityStoreManager;
    }
    
    [_containerWindowController showWindow: nil];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - Dirs

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory: NSDocumentDirectory inDomains: NSUserDomainMask] lastObject];
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(NSURL *)storeURL 
{
	return [[self applicationDocumentsDirectory] URLByAppendingPathComponent: @"Sample.sqlite"];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - Notifications

-(void)reloadData: (NSNotification *)notification
{
    if(!notification)
        return;
    
	// STEP 7a - Do not allow use of any NSManagedObjectContext until UbiquityStoreManager is ready
    if(_ubiquityStoreManager.isReady)
    {
        [self fetchData];
        
        // STEP 5b - Display current state of the UbiquityStoreManager
        [_iCloudButton setState: _ubiquityStoreManager.iCloudEnabled];
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)refreshViews: (NSNotification *)notification
{
    [self fetchData];
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - Core Data

-(void)fetchData
{
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName: @"Event"];
    [self.managedObjectContext performBlockAndWait: ^(){
        NSError *error = nil;
        
        _events = [[self.managedObjectContext executeFetchRequest: request error: &error] mutableCopy];
        if(error)
            [[NSApplication sharedApplication] presentError: error];
        
        [self.tableView reloadData];
    }];
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)saveContext 
{
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
	
    if(managedObjectContext) 
    {
        if([managedObjectContext hasChanges]) 
        {
			[managedObjectContext performBlockAndWait: ^{
				NSError *error = nil;
                
				if(![managedObjectContext save: &error]) 
                    [[NSApplication sharedApplication] presentError: error];
			}];
        } 
    }
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(NSManagedObjectModel *)managedObjectModel
{
    if (__managedObjectModel)
        return __managedObjectModel;
    
    __managedObjectModel = [NSManagedObjectModel mergedModelFromBundles: nil];
    return __managedObjectModel;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(NSPersistentStoreCoordinator *)persistentStoreCoordinator 
{
    // STEP 3 - Get the persistentStoreCoordinator from the UbiquityStoreManager
    if(!__persistentStoreCoordinator) 
        __persistentStoreCoordinator = [_ubiquityStoreManager persistentStoreCoordinator];
    
    return __persistentStoreCoordinator;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(NSManagedObjectContext *)managedObjectContext
{
    if(__managedObjectContext)
        return __managedObjectContext;
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
	
    if(coordinator) 
    {
		NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType: NSMainQueueConcurrencyType];
        
        [moc performBlockAndWait: ^{
            [moc setPersistentStoreCoordinator: coordinator];
		}];
		
        __managedObjectContext = moc;
 		__managedObjectContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
	}
     
    return __managedObjectContext;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - Entities

-(User *)primaryUser 
{
	// Make sure there is an primary user
	User *primaryUser = [User primaryUserInContext: self.managedObjectContext];
	if(!primaryUser) 
    {			
		// Create and save the default user
		primaryUser = [User insertedNewUserInManagedObjectContext: self.managedObjectContext];
		primaryUser.primary = YES;
		[self saveContext];
    }
    
	return primaryUser;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - NSTableViewDelegate & DataSource

-(NSInteger)numberOfRowsInTableView: (NSTableView *)tableView
{
	// STEP 7b - Do not allow use of any NSManagedObjectContext until UbiquityStoreManager is ready
    if(!_ubiquityStoreManager.isReady)
        return 0;
    
    return [_events count];
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(id)tableView: (NSTableView *)tableView objectValueForTableColumn: (NSTableColumn *)tableColumn row: (NSInteger)row
{
    NSManagedObject *object = [_events objectAtIndex: row];
    
    if(object)
        return [[object valueForKey: @"timeStamp"] description];
    
    return nil;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(NSIndexSet *)tableView: (NSTableView *)tableView selectionIndexesForProposedSelection: (NSIndexSet *)proposedSelectionIndexes
{
    [_removeButton setEnabled: proposedSelectionIndexes.count > 0];
    
    return proposedSelectionIndexes;
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - UbiquityStoreManagerDelegate

// STEP 4 - Implement the UbiquityStoreManager delegate methods
-(NSManagedObjectContext *)managedObjectContextForUbiquityStoreManager: (UbiquityStoreManager *)usm 
{
	return self.managedObjectContext;
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)ubiquityStoreManager: (UbiquityStoreManager *)manager didSwitchToiCloud: (BOOL)didSwitch 
{
    [self.iCloudButton setState: didSwitch];
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)ubiquityStoreManager :(UbiquityStoreManager *)manager didEncounterError: (NSError *)error cause: (UbiquityStoreManagerErrorCause)cause context: (id)context 
{
	NSLog(@"UbiquityStoreManager ERROR: %@", [error description]);
}

///////////////////////////////////////////////////////////////////////////////////////////////////

-(void)ubiquityStoreManager: (UbiquityStoreManager *)manager log: (NSString *)message 
{
	NSLog(@"UbiquityStoreManager: %@", message);
}

@end
