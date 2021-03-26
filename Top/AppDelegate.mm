//
//  AppDelegate.m
//  Top
//
//  Created by Aous Naman on 1/10/2015.
//  Copyright © 2015 Aous Naman. All rights reserved.
//

#include <sys/sysctl.h>
#include <sys/types.h>
#include <mach/mach.h>
#include <mach/processor_info.h>
#include <mach/mach_host.h>

#import "AppDelegate.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate
{
  NSStatusItem *item;
  NSMenu *menu;
  NSImage *image;
  int width, height;
  NSColor *color;

  NSTimer *updateTimer;
  int num_cpus;
  unsigned long *system_ticks, *user_ticks, *idle_ticks;
}

- (void)developImage:(float) factor {
  [image lockFocus];
  [color set];
  NSRectFill(NSMakeRect(0, 0, width, height));

  float t = (height - 2) * factor + 1;
  [image drawInRect:NSMakeRect(1, t, width - 2, height - 1 - t)
           fromRect:NSZeroRect
          operation:NSCompositeClear
           fraction:0];
  [image unlockFocus];

}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {

  //initialize stuff
  num_cpus = 0;
  system_ticks = user_ticks = idle_ticks = NULL;
  color = [NSColor blackColor];
  width = 8;
  height = 20;

  //bar
  NSStatusBar *sys_bar = [NSStatusBar systemStatusBar];
  item = [sys_bar statusItemWithLength:NSVariableStatusItemLength];

  //image
  image = [[NSImage alloc] initWithSize:NSMakeSize(width, height)];
  [image setTemplate:YES];
  [self developImage:0.0f];
  item.image = image;
  item.toolTip = [NSString stringWithFormat:@"CPU Utilization   0.0%%"];

  //menu
  menu = [[NSMenu alloc] init];
  [menu addItemWithTitle:@"Quit"
                  action:@selector(terminate:)
           keyEquivalent:@"q"];
  item.menu = menu;

  //timer
  updateTimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                 target:self
                                               selector:@selector(updateInfo:)
                                               userInfo:nil
                                                repeats:YES];
}

- (void)updateInfo:(NSTimer *)timer
{
  natural_t cur_num_cpus;
  processor_info_array_t info_array;
  mach_msg_type_number_t info_count;
  kern_return_t res;
  
  res = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO,
                            &cur_num_cpus, &info_array, &info_count);
  if (res == KERN_SUCCESS) {
    if (cur_num_cpus != num_cpus) {
      delete[] system_ticks;
      system_ticks = new unsigned long[cur_num_cpus];
      delete[] user_ticks;
      user_ticks = new unsigned long[cur_num_cpus];
      delete[] idle_ticks;
      idle_ticks = new unsigned long[cur_num_cpus];
      num_cpus = cur_num_cpus;
      for (int i = 0; i < num_cpus; ++i)
        system_ticks[i] = user_ticks[i] = idle_ticks[i] = 0;
    }

    processor_cpu_load_info_data_t *cpu_load_info;
    cpu_load_info = (processor_cpu_load_info_data_t*) info_array;

    float utilization_sum = 0;
    for (int i = 0; i < num_cpus; ++i) {
      unsigned long system = cpu_load_info[i].cpu_ticks[CPU_STATE_SYSTEM];
      system -= system_ticks[i];
      system_ticks[i] = cpu_load_info[i].cpu_ticks[CPU_STATE_SYSTEM];
      unsigned long user = cpu_load_info[i].cpu_ticks[CPU_STATE_USER];
      user -= user_ticks[i];
      user_ticks[i] = cpu_load_info[i].cpu_ticks[CPU_STATE_USER];
      unsigned long idle = cpu_load_info[i].cpu_ticks[CPU_STATE_IDLE];
      idle -= idle_ticks[i];
      idle_ticks[i] = cpu_load_info[i].cpu_ticks[CPU_STATE_IDLE];
      unsigned long total = system + user + idle;
      float cpu_util = (float)(system + user) / total;
      utilization_sum += (cpu_util <= 1.0f) ? cpu_util : 1.0f;
//      printf("Core %d util = %f\n", i, cpu_util);
    }

    vm_deallocate(mach_task_self(), (vm_address_t)info_array, info_count);

    float util = utilization_sum / num_cpus;
    [self developImage : util];
    [item setImage:image];
    item.toolTip = [NSString stringWithFormat:@"CPU Utilization %5.1f%%",
                    util * 100.0f];
  } else {
    NSLog(@"Error!");
    [NSApp terminate:nil];
  }
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
  // Insert code here to tear down your application
  NSStatusBar *sys_bar = [NSStatusBar systemStatusBar];
  [sys_bar removeStatusItem:item];
  [updateTimer invalidate];
  updateTimer = nil;
  delete[] system_ticks;
  delete[] user_ticks;
  delete[] idle_ticks;
}

@end
