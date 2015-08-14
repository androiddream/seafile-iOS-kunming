//
//  SeafProviderFileViewController.m
//  seafilePro
//
//  Created by Wang Wei on 11/14/14.
//  Copyright (c) 2014 Seafile. All rights reserved.
//

#import "SeafProviderFileViewController.h"
#import "SeafFile.h"
#import "SeafRepos.h"
#import "SeafGlobal.h"
#import "FileSizeFormatter.h"
#import "SeafDateFormatter.h"
#import "Utils.h"
#import "Debug.h"

@interface SeafProviderFileViewController ()<SeafDentryDelegate, SeafUploadDelegate, UIScrollViewDelegate>
@property (strong, nonatomic) IBOutlet  UIButton *chooseButton;
@property (strong, nonatomic) IBOutlet  UIButton *backButton;
@property (strong, nonatomic) IBOutlet  UILabel *titleLabel;
@property (strong, nonatomic) IBOutlet  UIActivityIndicatorView *loadingView;

@property (strong, nonatomic) UIProgressView* progressView;
@property (strong) UIAlertController *alert;
@property (strong) SeafFile *sfile;
@property (strong) SeafUploadFile *ufile;
@property (strong) NSArray *items;
@property BOOL clearall;
@end

@implementation SeafProviderFileViewController

- (NSFileCoordinator *)fileCoordinator
{
    NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] init];
    [fileCoordinator setPurposeIdentifier:APP_ID];
    return fileCoordinator;
}

- (void)setDirectory:(SeafDir *)directory
{
    _directory = directory;
    _directory.delegate = self;
    [_directory loadContent:true];
    self.titleLabel.text = _directory.name;
}

- (UIProgressView *)progressView
{
    if (!_progressView) {
        _progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
    }
    return _progressView;
}

- (void)refreshView
{
    self.titleLabel.text = _directory.name;
    if (self.root.documentPickerMode == UIDocumentPickerModeImport
        || self.root.documentPickerMode == UIDocumentPickerModeOpen) {
        self.items = _directory.items;
        self.chooseButton.hidden = true;
    } else {
        NSMutableArray *arr = [[NSMutableArray alloc] init];
        for (SeafBase *entry in _directory.items) {
            if ([entry isKindOfClass:[SeafDir class]])
                [arr addObject:entry];
        }
        self.items = arr;
        self.chooseButton.hidden = [_directory isKindOfClass:[SeafRepos class]];
    }

    if (self.chooseButton.hidden)
        self.tableView.sectionHeaderHeight = 1;
    else
        self.tableView.sectionHeaderHeight = 22;

    if ([self isViewLoaded]) {
        [self.tableView reloadData];
        if (_directory && !_directory.hasCache) {
            [self showLodingView];
        } else {
            [self dismissLoadingView];
        }
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.rowHeight = 50;
    _clearall = false;
    [self refreshView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)showLodingView
{
    if (!self.loadingView) {
        self.loadingView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        self.loadingView.color = [UIColor darkTextColor];
        self.loadingView.hidesWhenStopped = YES;
        [self.tableView addSubview:self.loadingView];
    }
    self.loadingView.center = self.view.center;
    self.loadingView.frame = CGRectMake((self.view.frame.size.width-self.loadingView.frame.size.width)/2, (self.view.frame.size.height-self.loadingView.frame.size.height)/2, self.loadingView.frame.size.width, self.loadingView.frame.size.height);
    if (![self.loadingView isAnimating])
        [self.loadingView startAnimating];
}

- (void)viewDidAppear:(BOOL)animated
{
    if (self.loadingView && [self.loadingView isAnimating]) {
        self.loadingView.frame = CGRectMake((self.view.frame.size.width-self.loadingView.frame.size.width)/2, (self.view.frame.size.height-self.loadingView.frame.size.height)/2, self.loadingView.frame.size.width, self.loadingView.frame.size.height);
    }
}

- (void)dismissLoadingView
{
    [self.loadingView stopAnimating];
}

- (void)alertWithTitle:(NSString*)message handler:(void (^)())handler
{
    [Utils alertWithTitle:message message:nil handler:handler from:self];
}

- (IBAction)goBack:(id)sender
{
    [self popViewController];
}

- (void)showUploadProgress:(SeafUploadFile *)file
{
    NSString *title = [NSString stringWithFormat: @"Uploading %@", file.name];
    self.alert = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Seafile") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [file doRemove];
    }];
    self.ufile = file;
    [self.alert addAction:cancelAction];
    [self presentViewController:self.alert animated:true completion:^{
        self.progressView.progress = 0.f;
        CGRect r = self.alert.view.frame;
        self.progressView.frame = CGRectMake(20, r.size.height-45, r.size.width - 40, 20);
        [self.alert.view addSubview:self.progressView];
        [self.ufile doUpload];
    }];
}

- (IBAction)chooseCurrentDir:(id)sender
{
    NSURL *url = [self.root.documentStorageURL URLByAppendingPathComponent:self.root.originalURL.lastPathComponent];
    Debug("Upload file: %@ to %@", url, _directory.path);
    [self.fileCoordinator coordinateWritingItemAtURL:url options:0 error:NULL byAccessor:^(NSURL *newURL) {
        NSURL *realURL = [Utils copyFile:self.root.originalURL to:newURL];
        if (!realURL) {
            Warning("Failed to copy file:%@", self.root.originalURL);
            return;
        }
        SeafUploadFile *ufile = [[SeafUploadFile alloc] initWithPath:realURL.path];
        ufile.delegate = self;
        ufile.udir = _directory;
        [self showUploadProgress:ufile];
    }];
}

- (void)popupSetRepoPassword:(SeafRepo *)repo
{
    [Utils popupInputView:NSLocalizedString(@"Password of this library", @"Seafile") placeholder:nil secure:true handler:^(NSString *input) {
        if (!input || input.length == 0) {
            [self alertWithTitle:NSLocalizedString(@"Password must not be empty", @"Seafile")handler:^{
                [self popupSetRepoPassword:repo];
            }];
            return;
        }
        if (input.length < 3 || input.length  > 100) {
            [self alertWithTitle:NSLocalizedString(@"The length of password should be between 3 and 100", @"Seafile") handler:^{
                [self popupSetRepoPassword:repo];
            }];
            return;
        }
        [repo setDelegate:self];
        if ([repo->connection localDecrypt:repo.repoId])
            [repo checkRepoPassword:input];
        else
            [repo setRepoPassword:input];
    } from:self];
}

- (void)reloadTable:(BOOL)clearall
{
    _clearall = clearall;
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _clearall ? 0 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.items.count;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (self.chooseButton.hidden) {
        UIView *lineView = [[UIView alloc] initWithFrame:CGRectMake(0.0f, 0.0f, tableView.frame.size.width, 1.0f)];
        [lineView setBackgroundColor:[UIColor lightGrayColor]];
        return lineView;
    } else {
        UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 30)];
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10, 3, tableView.bounds.size.width - 10, 18)];
        label.text = @"Save Destination";
        label.textColor = [UIColor whiteColor];
        label.backgroundColor = [UIColor clearColor];
        [headerView setBackgroundColor:HEADER_COLOR];
        [headerView addSubview:label];
        return headerView;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *CellIdentifier = @"SeafProviderCell2";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    SeafBase *entry;
    @try {
        entry = [self.items objectAtIndex:indexPath.row];
    } @catch(NSException *exception) {
        return cell;
    }
    cell.textLabel.text = entry.name;
    cell.textLabel.font = [UIFont systemFontOfSize:17];
    cell.textLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    cell.imageView.image = entry.icon;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:13];
    if ([entry isKindOfClass:[SeafRepo class]]) {
        SeafRepo *srepo = (SeafRepo *)entry;
        NSString *detail = [NSString stringWithFormat:@"%@, %@", [FileSizeFormatter stringFromNumber:[NSNumber numberWithUnsignedLongLong:srepo.size ] useBaseTen:NO], [SeafDateFormatter stringFromLongLong:srepo.mtime]];
        cell.detailTextLabel.text = detail;
    } else if ([entry isKindOfClass:[SeafDir class]]) {
        cell.detailTextLabel.text = nil;
    } else if ([entry isKindOfClass:[SeafFile class]]) {
        SeafFile *sfile = (SeafFile *)entry;
        cell.detailTextLabel.text = sfile.detailText;
    }
    cell.imageView.frame = CGRectMake(8, 8, 28, 28);
    return cell;
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

#pragma mark - Table view delegate

- (void)showDownloadProgress:(SeafFile *)file
{
    NSString *title = [NSString stringWithFormat: @"Downloading %@", file.name];
    self.alert = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"Seafile") style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [file cancelDownload];
    }];
    self.sfile = file;
    [self.alert addAction:cancelAction];
    [self presentViewController:self.alert animated:true completion:^{
        self.progressView.progress = 0.f;
        CGRect r = self.alert.view.frame;
        self.progressView.frame = CGRectMake(20, r.size.height-45, r.size.width - 40, 20);
        [self.alert.view addSubview:self.progressView];
        [file load:self force:NO];
    }];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    SeafBase *entry;
    @try {
        entry = [self.items objectAtIndex:indexPath.row];
    } @catch(NSException *exception) {
        [self performSelector:@selector(reloadData) withObject:nil afterDelay:0.1];
        return;
    }
    if ([entry isKindOfClass:[SeafFile class]]) {
        SeafFile *file = (SeafFile *)entry;
        if (![file hasCache]) {
            [self showDownloadProgress:file];
            return;
        }
        if (self.root.documentPickerMode == UIDocumentPickerModeImport
            || self.root.documentPickerMode == UIDocumentPickerModeOpen) {
            NSURL *exportURL = [file exportURL];
            Debug("file exportURL:%@", exportURL);
            NSURL *url = [self.root.documentStorageURL URLByAppendingPathComponent:exportURL.lastPathComponent];
            [self.fileCoordinator coordinateWritingItemAtURL:url options:0 error:NULL byAccessor:^(NSURL *newURL) {
                NSURL *realURL = [Utils copyFile:exportURL to:newURL];
                if (realURL) {
                    if (self.root.documentPickerMode == UIDocumentPickerModeOpen) {
                        NSString *key = [NSString stringWithFormat:@"EXPORTED/%@", realURL.lastPathComponent];
                        [SeafGlobal.sharedObject setObject:file.toDict forKey:key];
                        [SeafGlobal.sharedObject synchronize];
                    }
                    [self.root dismissGrantingAccessToURL:realURL];
                } else {
                    Warning("Failed to copy file %@", file.name);
                }
            }];
        }
    } else if ([entry isKindOfClass:[SeafRepo class]] && [(SeafRepo *)entry passwordRequired]) {
        [self popupSetRepoPassword:(SeafRepo *)entry];
    } else if ([entry isKindOfClass:[SeafDir class]]) {
        [self pushViewControllerDir:(SeafDir *)entry];
    }
}

#pragma mark - SeafDentryDelegate
- (void)entry:(SeafBase *)entry updated:(BOOL)updated progress:(int)percent
{
    if (![self isViewLoaded])
        return;

    if (_directory == entry) {
        if (updated && percent == 100)
            [self refreshView];
    } else {
        if (entry != self.sfile) return;
        NSUInteger index = [_directory.allItems indexOfObject:entry];
        if (index == NSNotFound)
            return;
        self.progressView.progress = percent * 1.0f/100.f;
        if (percent == 100) {
            [self.alert dismissViewControllerAnimated:NO completion:^{
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
                //[self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                [self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
            }];
        }
    }
}
- (void)entry:(SeafBase *)entry downloadingFailed:(NSUInteger)errCode
{
    if (_directory == entry) {
        if ([_directory hasCache])
            return;

        Warning("Failed to load directory content %@\n", entry.name);
    } else {
        if (entry != self.sfile) return;
        [self.alert dismissViewControllerAnimated:NO completion:^{
            NSUInteger index = [_directory.allItems indexOfObject:entry];
            if (index == NSNotFound)
                return;
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
            [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
            Warning("Failed to download file %@\n", entry.name);
            NSString *msg = [NSString stringWithFormat:@"Failed to download file '%@'", entry.name];
            [self alertWithTitle:msg handler:nil];
        }];
    }
}

- (void)entry:(SeafBase *)entry repoPasswordSet:(BOOL)success
{
    if (success) {
        [self pushViewControllerDir:(SeafDir *)entry];
    } else {
        [self performSelector:@selector(popupSetRepoPassword:) withObject:entry afterDelay:1.0];
    }
}

#pragma mark - SeafUploadDelegate
- (void)uploadProgress:(SeafUploadFile *)file result:(BOOL)res progress:(int)percent
{
    if (self.ufile != file) return;
    if (res) {
        self.progressView.progress = percent * 1.0f/100.f;
    } else {
        Warning("Failed to upload file %@", file.name);
        [self alertWithTitle:NSLocalizedString(@"Failed to uplod file", @"Seafile") handler:nil];
    }
}

- (void)uploadSucess:(SeafUploadFile *)file oid:(NSString *)oid
{
    if (self.ufile != file) return;
    [self.alert dismissViewControllerAnimated:NO completion:^{
        [self.root dismissGrantingAccessToURL:[NSURL URLWithString:file.lpath]];
    }];
}

- (void)pushViewControllerDir:(SeafDir *)dir
{
    SeafProviderFileViewController *controller = [[UIStoryboard storyboardWithName:@"SeafProviderFileViewController" bundle:nil] instantiateViewControllerWithIdentifier:@"SeafProviderFileViewController"];
    controller.directory = dir;
    controller.root = self.root;
    controller.view.frame = CGRectMake(self.view.frame.size.width, self.view.frame.origin.y, self.view.frame.size.width, self.view.frame.size.height);
    @synchronized (self) {
        if (self.childViewControllers.count > 0)
            return;
        [self addChildViewController:controller];
    }
    [controller didMoveToParentViewController:self];
    [self.view addSubview:controller.view];
    [self.view bringSubviewToFront:controller.view];

    [UIView animateWithDuration:0.5f delay:0.f options:0 animations:^{
        controller.view.frame = self.view.frame;
    } completion:^(BOOL finished) {
        [self reloadTable:true];
    }];
}

- (void)popViewController
{
    if ([self.parentViewController isKindOfClass:[SeafProviderFileViewController class]])
        [(SeafProviderFileViewController *)self.parentViewController reloadTable:false];
    [UIView animateWithDuration:0.5
                     animations:^{
                         self.view.frame = CGRectMake(self.view.frame.size.width, self.view.frame.origin.y, self.view.frame.size.width, self.view.frame.size.height);
                     }
                     completion:^(BOOL finished){
                         [self willMoveToParentViewController:self.parentViewController];
                         [self removeFromParentViewController];
                         [self.view removeFromSuperview];
                     }];
}

@end
