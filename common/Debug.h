//
//  Debug.h
//  seafile
//
//  Created by Wang Wei on 10/8/12.
//  Copyright (c) 2012 Seafile Ltd. All rights reserved.
//

#import <UIKit/UIKit.h>

#define APP_NAME @"Seafile"

//#define GROUP_NAME @"group.com.seafile.seafilePro"
//#define APP_ID @"com.seafile.seafilePro"
#define GROUP_NAME @"group.tqb.taoqian123.com"
#define APP_ID @"com.seafile.seafilePro2"

#define API_URL  @"/api2"
#if DEBUG
#define Debug(fmt, args...) NSLog(@"#%d %s %@:" fmt, __LINE__, __FUNCTION__, [NSThread currentThread], ##args)
#else
#define Debug(fmt, args...) do{}while(0)
#endif

#define Warning(fmt, args...) NSLog(@"#%d %s:[WARNING]" fmt, __LINE__, __FUNCTION__, ##args)

static inline BOOL IsIpad()
{
    return ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad);
}

#define ios7 ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7)
#define ios8 ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8)


//#define BAR_COLOR     [UIColor colorWithRed:240.0/256 green:128.0/256 blue:48.0/256 alpha:1.0]
#define BAR_COLOR     [UIColor colorWithRed:46.0/256 green:141.0/256 blue:230.0/256 alpha:1.0]
#define HEADER_COLOR     BAR_COLOR
#define SEAF_COLOR_DARK BAR_COLOR
#define SEAF_COLOR_LIGHT BAR_COLOR

//#define HEADER_COLOR     [UIColor colorWithRed:246.0/256 green:176.0/256 blue:90.0/256 alpha:1.0]
//#define SEAF_COLOR_DARK [UIColor colorWithRed:236.0/256 green:114.0/256 blue:31.0/256 alpha:1.0]
//#define SEAF_COLOR_LIGHT [UIColor colorWithRed:255.0/256 green:196.0/256 blue:115.0/256 alpha:1.0]
