//
//  AppDelegate.h
//  iCloudStoreManagerExampleMac
//
//  Created by Heiko Dreyer on 21.06.12.
//  Copyright (c) 2012 boxedfolder.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "ContainerWindowController.h"
#import "UbiquityStoreManager.h"

@interface AppDelegate : NSObject <NSApplicationDelegate, UbiquityStoreManagerDelegate, NSTableViewDelegate, NSTableViewDataSource>

@property (assign)IBOutlet NSWindow *window;
@property (assign)IBOutlet NSButton *iCloudButton;
@property (assign)IBOutlet NSButton *removeButton;
@property (assign)IBOutlet NSTableView *tableView;

@property (readonly, strong, nonatomic)NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, strong, nonatomic)NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic)NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic)UbiquityStoreManager *ubiquityStoreManager;
@property (readonly, strong, nonatomic)NSMutableArray *events;

@property (readonly, strong, nonatomic)ContainerWindowController *containerWindowController;

-(void)saveContext;

-(IBAction)add: (id)sender;
-(IBAction)remove: (id)sender;
-(IBAction)clear: (id)sender;
-(IBAction)useiCloud: (id)sender;
-(IBAction)viewContainer: (id)sender;

@end
