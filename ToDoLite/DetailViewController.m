//
//  DetailViewController.m
//  ToDoLite
//
//  Created by Pasin Suriyentrakorn on 10/11/14.
//  Copyright (c) 2014 Pasin Suriyentrakorn. All rights reserved.
//

#import "DetailViewController.h"
#import "AppDelegate.h"
#import "Task.h"
#import "Profile.h"
#import "ShareViewController.h"
#import "ImageViewController.h"

#define ImageDataContentType @"image/jpg"

@interface DetailViewController () {
    Task *taskToAddImageTo;
    UIImage *imageForNewTask;
    UIImage *imageToDisplay;
    UIView *imageActionSheetSenderView;
    UIPopoverController *imagePickerPopover;
}

@property CBLDatabase *database;
@property CBLLiveQuery *liveQuery;
@property NSArray *tasks;

@end

@implementation DetailViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.title = self.list.title;
    self.addImageButton.enabled = YES;
    self.addItemTextField.enabled = YES;

    self.liveQuery = [[self.list queryTasks] asLiveQuery];
    [self.liveQuery addObserver:self forKeyPath:@"rows" options:0 context:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    // Hide the share button if the current user is guest or is not the owner of the list:
    AppDelegate *app = [[UIApplication sharedApplication] delegate];
    if (![app.currentUserId isEqualToString:self.list.owner.user_id])
        self.navigationItem.rightBarButtonItem = nil;

    NSIndexPath *selected = [self.tableView indexPathForSelectedRow];
    if (selected)
        [self.tableView deselectRowAtIndexPath:selected animated:NO];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)dealloc {
    [self.liveQuery removeObserver:self forKeyPath:@"rows"];
}


#pragma mark - KVO Observer for live query

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change
                       context:(void *)context {
    self.tasks = self.liveQuery.rows.allObjects;
    [self.tableView reloadData];
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"share"]) {
        ShareViewController *controller = (ShareViewController *)[segue destinationViewController];
        controller.list = self.list;
    } else if ([[segue identifier] isEqualToString:@"showImage"]) {
        ImageViewController *controller = (ImageViewController *)[segue destinationViewController];
        controller.image = imageToDisplay;
        imageToDisplay = nil;
    }
}

#pragma mark - Text Field

// Called when the text field's Return key is tapped.
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    NSString *title = _addItemTextField.text;
    if (title.length == 0) {
        return NO;  // Nothing entered
    }
    [_addItemTextField setText:nil];

    NSData *image = imageForNewTask ? [self dataForImage:imageForNewTask] : nil;
    Task *task = [self.list addTaskWithTitle:title
                                   withImage:image
                        withImageContentType:ImageDataContentType];
    NSError *error;
    if ([task save:&error]) {
        imageForNewTask = nil;
        [self updateAddImageButtonWithImage:nil];
    } else {
        AppDelegate *app = [[UIApplication sharedApplication] delegate];
        [app showMessage:@"Couldn't save new task" withTitle:@"Error"];
    }

    [textField resignFirstResponder];

    return YES;
}

#pragma mark - UIImagePicker

- (BOOL)hasCamera {
    return [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
}

- (void)displayAddImageActionSheetFor:(UIView *)sender forTask:(Task *)task {
    taskToAddImageTo = task;
    imageActionSheetSenderView = sender;

    UIActionSheet *actionSheet = [[UIActionSheet alloc] init];

    if ([self hasCamera]) [actionSheet addButtonWithTitle:@"Take Photo"];
    [actionSheet addButtonWithTitle:@"Choose Existing"];
    if (imageForNewTask)[actionSheet addButtonWithTitle:@"Delete"];
    [actionSheet addButtonWithTitle:@"Cancel"];

    [actionSheet setCancelButtonIndex:actionSheet.numberOfButtons - 1];
    [actionSheet setDelegate:self];
    [actionSheet showFromRect:sender.frame inView:[sender superview] animated:YES];
}

- (void)displayImagePickerForSender:(UIView *)senderView
                         sourceType:(UIImagePickerControllerSourceType)sourceType {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.sourceType = sourceType;
    picker.allowsEditing = YES;
    picker.delegate = self;

    imagePickerPopover = nil;

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad &&
        sourceType == UIImagePickerControllerSourceTypePhotoLibrary) {
            CGRect displayFrame = [[senderView superview]
                                   convertRect:senderView.frame toView:self.view];
            imagePickerPopover = [[UIPopoverController alloc] initWithContentViewController:picker];
            [imagePickerPopover presentPopoverFromRect:displayFrame
                                                inView:self.view
                              permittedArrowDirections:UIPopoverArrowDirectionAny
                                              animated:YES];
    } else {
        [self presentViewController:picker animated:YES completion:^{ }];
    }
}

- (void)updateAddImageButtonWithImage:(UIImage *)image {
    if (image) {
        [_addImageButton setImage:image forState:UIControlStateNormal];
    } else {
        [_addImageButton setImage:[UIImage imageNamed:@"Camera"] forState:UIControlStateNormal];
    }
}

- (NSData *)dataForImage:(UIImage *)image {
    return UIImageJPEGRepresentation(image, 0.5);
}

- (IBAction)addImageButtonAction:(UIButton *)sender {
    [self.addItemTextField resignFirstResponder];
    [self displayAddImageActionSheetFor:sender forTask:nil];
}

#pragma mark - UIImagePickerViewDelegate

- (void)imagePickerController:(UIImagePickerController *)picker
didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *selectedImage = (UIImage *) [info objectForKey:UIImagePickerControllerEditedImage];
    if (taskToAddImageTo) {
        [taskToAddImageTo setImage:
            [self dataForImage:selectedImage] contentType:ImageDataContentType];

        NSError *error;
        if (![taskToAddImageTo save:&error]) {
            AppDelegate *app = [[UIApplication sharedApplication] delegate];
            [app showMessage:@"Couldn't save the image to the task" withTitle:@"Error"];
        }
    } else {
        // new task
        imageForNewTask = selectedImage;
        [self updateAddImageButtonWithImage:imageForNewTask];
    }

    if (imagePickerPopover) {
        [imagePickerPopover dismissPopoverAnimated:YES];
    } else {
        [picker.presentingViewController dismissViewControllerAnimated:YES completion:^{ }];
    }
}

#pragma mark - ActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == actionSheet.cancelButtonIndex) {
        return;
    }

    if (imageForNewTask && buttonIndex == actionSheet.cancelButtonIndex - 1) {
        [self updateAddImageButtonWithImage:nil];
        imageForNewTask = nil;
        return;
    }

    UIImagePickerControllerSourceType sourceType = ([self hasCamera] && buttonIndex == 0) ?
    UIImagePickerControllerSourceTypeCamera : UIImagePickerControllerSourceTypePhotoLibrary;

    dispatch_async(dispatch_get_main_queue(), ^{
        [self displayImagePickerForSender:imageActionSheetSenderView sourceType:sourceType];
    });
}

#pragma mark - Table View Datasource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.tasks.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TaskTableViewCell *cell = (TaskTableViewCell *)
        [tableView dequeueReusableCellWithIdentifier:@"Task" forIndexPath:indexPath];
    CBLQueryRow* row = [self.tasks objectAtIndex:indexPath.row];
    Task *task = [Task modelForDocument:row.document];
    cell.task = task;
    cell.delegate = self;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CBLQueryRow* row = [self.tasks objectAtIndex:indexPath.row];
    Task *task = [Task modelForDocument:row.document];
    task.checked = !task.checked;

    NSError *error;
    if (![task save:&error]) {
        AppDelegate *app = [[UIApplication sharedApplication] delegate];
        [app showMessage:@"Failed to update the task" withTitle:@"Error"];
    }
}

- (void)didSelectImageButton:(UIButton *)imageButton ofTask:(Task *)task {
    [self.addItemTextField resignFirstResponder];
    CBLAttachment *attachment = [task attachmentNamed:@"image"];
    if (attachment) {
        imageToDisplay = [UIImage imageWithData:attachment.content];
        [self performSegueWithIdentifier: @"showImage" sender: self];
    } else {
        [self displayAddImageActionSheetFor:imageButton forTask:task];
    }
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)style
forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (style == UITableViewCellEditingStyleDelete) {
        CBLQueryRow* row = [self.tasks objectAtIndex:indexPath.row];
        Task *task = [Task modelForDocument:row.document];
        [task deleteTask:nil];
    }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self.addItemTextField resignFirstResponder];
}

@end
