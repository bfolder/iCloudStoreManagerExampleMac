//
//  ContainerWindowController.h
//  iCloudStoreManagerExampleMac
//
//  Created by Heiko Dreyer on 21.06.12.
//  Copyright (c) 2012 boxedfolder.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "UbiquityStoreManager.h"

@interface ContainerWindowController : NSWindowController <NSTableViewDelegate, NSTableViewDataSource>

@property (strong, nonatomic)UbiquityStoreManager *ubiquityStoreManager;

@property (assign)IBOutlet NSTableView *tableView;

-(IBAction)refreshList: (id)sender;

@end
