//
//  MQImageCellModel.m
//  MeiQiaSDK
//
//  Created by ijinmao on 15/10/29.
//  Copyright © 2015年 MeiQia Inc. All rights reserved.
//

#import "MQImageCellModel.h"
#import "MQChatBaseCell.h"
#import "MQImageMessageCell.h"
#import "MQChatViewConfig.h"

@interface MQImageCellModel()

/**
 * @brief cell中消息的id
 */
@property (nonatomic, readwrite, strong) NSString *messageId;

/**
 * @brief cell的高度
 */
@property (nonatomic, readwrite, assign) CGFloat cellHeight;

/**
 * @brief 图片path
 */
//@property (nonatomic, readwrite, copy) NSString *imagePath;

/**
 * @brief 图片image(当imagePath不存在时使用)
 */
@property (nonatomic, readwrite, strong) UIImage *image;

/**
 * @brief 消息的时间
 */
@property (nonatomic, readwrite, copy) NSDate *date;

/**
 * @brief 发送者的头像Path
 */
@property (nonatomic, readwrite, copy) NSString *avatarPath;

/**
 * @brief 发送者的头像的图片 (如果在头像path不存在的情况下，才使用这个属性)
 */
@property (nonatomic, readwrite, copy) UIImage *avatarLocalImage;

/**
 * @brief 聊天气泡的image（该气泡image已经进行了resize）
 */
@property (nonatomic, readwrite, copy) UIImage *bubbleImage;

/**
 * @brief 消息气泡的frame
 */
@property (nonatomic, readwrite, assign) CGRect bubbleImageFrame;

/**
 * @brief 发送者的头像frame
 */
@property (nonatomic, readwrite, assign) CGRect avatarFrame;

/**
 * @brief 发送状态指示器的frame
 */
@property (nonatomic, readwrite, assign) CGRect sendingIndicatorFrame;

/**
 * @brief 读取照片的指示器的frame
 */
@property (nonatomic, readwrite, assign) CGRect loadingIndicatorFrame;

/**
 * @brief 发送出错图片的frame
 */
@property (nonatomic, readwrite, assign) CGRect sendFailureFrame;

/**
 * @brief 消息的来源类型
 */
@property (nonatomic, readwrite, assign) MQChatCellFromType cellFromType;

@end

@implementation MQImageCellModel

#pragma initialize
/**
 *  根据MQMessage内容来生成cell model
 */
- (MQImageCellModel *)initCellModelWithMessage:(MQImageMessage *)message cellWidth:(CGFloat)cellWidth {
    if (self = [super init]) {
        self.messageId = message.messageId;
        self.sendType = MQChatCellSending;
        self.date = message.date;
        self.avatarPath = @"";
        self.avatarLocalImage = [MQChatViewConfig sharedConfig].agentDefaultAvatarImage;
        if (message.userAvatarPath) {
            self.avatarPath = message.userAvatarPath;
        }
        
//        CGFloat bubbleWidth = cellWidth - kMQCellAvatarToHorizontalEdgeSpacing - kMQCellAvatarDiameter - kMQCellAvatarToBubbleSpacing - kMQCellBubbleMaxWidthToEdgeSpacing;
        //内容图片
        self.image = message.image;
//        self.imagePath = @"";
        if (!message.image) {
            if (message.imagePath.length > 0) {
                [self setModelsWithContentImage:[MQChatViewConfig sharedConfig].incomingBubbleImage message:message cellWidth:cellWidth];
                //新建线程读取远程图片
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:message.imagePath]];
                    if (imageData) {
                        UIImage *image = [UIImage imageWithData:imageData];
                        self.image = image;
                        if (self.delegate) {
                            if ([self.delegate respondsToSelector:@selector(didUpdateCellDataWithMessageId:)]) {
                                [self.delegate didUpdateCellDataWithMessageId:self.messageId];
                            }
                        }
                    } else {
#warning 这里增加加载图片出错的图片
                        self.image = [UIImage imageNamed:[MQChatFileUtil resourceWithName:@""]];
                    }
                    [self setModelsWithContentImage:self.image message:message cellWidth:cellWidth];
                });
            } else {
#warning 这里增加加载图片出错的图片
                self.image = [UIImage imageNamed:[MQChatFileUtil resourceWithName:@""]];
                [self setModelsWithContentImage:self.image message:message cellWidth:cellWidth];
            }
        } else {
            [self setModelsWithContentImage:self.image message:message cellWidth:cellWidth];
        }
        
    }
    return self;
}

//根据气泡中的图片生成其他model
- (void)setModelsWithContentImage:(UIImage *)contentImage
                          message:(MQImageMessage *)message
                        cellWidth:(CGFloat)cellWidth
{
    //限定图片的最大直径
    CGFloat maxBubbleDiameter = ceil(cellWidth / 2);  //限定图片的最大直径
    CGSize contentImageSize = contentImage.size;
    //先限定图片宽度来计算高度
    CGFloat bubbleWidth = contentImageSize.width < maxBubbleDiameter ? contentImageSize.width : maxBubbleDiameter;
    CGFloat bubbleHeight = ceil(contentImageSize.height/contentImageSize.width*bubbleWidth);
    //判断如果气泡高度计算结果超过图片的最大直径，则限制高度
    if (bubbleHeight > maxBubbleDiameter) {
        bubbleHeight = maxBubbleDiameter;
        bubbleWidth = ceil(contentImageSize.width / contentImageSize.height * bubbleHeight);
    }
    
    //根据消息的来源，进行处理
    UIImage *bubbleImage = [MQChatViewConfig sharedConfig].incomingBubbleImage;
    if (message.fromType == MQMessageOutgoing) {
        //发送出去的消息
        self.cellFromType = MQChatCellOutgoing;
        bubbleImage = [MQChatViewConfig sharedConfig].outgoingBubbleImage;
        
        //头像的frame
        //            self.avatarFrame = CGRectMake(cellWidth-kMQCellAvatarToHorizontalEdgeSpacing-kMQCellAvatarDiameter, kMQCellAvatarToVerticalEdgeSpacing, kMQCellAvatarDiameter, kMQCellAvatarDiameter);
        self.avatarFrame = CGRectMake(0, 0, 0, 0);
        //气泡的frame
        self.bubbleImageFrame = CGRectMake(cellWidth-kMQCellAvatarToBubbleSpacing-bubbleWidth, kMQCellAvatarToVerticalEdgeSpacing, bubbleWidth, bubbleHeight);
    } else {
        //收到的消息
        self.cellFromType = MQChatCellIncoming;
        
        //头像的frame
        self.avatarFrame = CGRectMake(kMQCellAvatarToHorizontalEdgeSpacing, kMQCellAvatarToVerticalEdgeSpacing, kMQCellAvatarDiameter, kMQCellAvatarDiameter);
        //气泡的frame
        self.bubbleImageFrame = CGRectMake(self.avatarFrame.origin.x+self.avatarFrame.size.width+kMQCellAvatarToBubbleSpacing, self.avatarFrame.origin.y, bubbleWidth, bubbleHeight);
    }
    
    //loading image的indicator
    self.loadingIndicatorFrame = CGRectMake(self.bubbleImageFrame.origin.x+self.bubbleImageFrame.size.width/2-kMQCellIndicatorDiameter/2, self.bubbleImageFrame.origin.y+self.bubbleImageFrame.size.height/2-kMQCellIndicatorDiameter/2, kMQCellIndicatorDiameter, kMQCellIndicatorDiameter);
    
    //气泡图片
    CGPoint centerArea = CGPointMake(bubbleImage.size.width / 4.0f, bubbleImage.size.height*3.0f / 4.0f);
    self.bubbleImage = [bubbleImage resizableImageWithCapInsets:UIEdgeInsetsMake(centerArea.y, centerArea.x, bubbleImage.size.height-centerArea.y+1, centerArea.x)];
    
    //发送消息的indicator的frame
    UIActivityIndicatorView *indicatorView = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(0, 0, kMQCellIndicatorDiameter, kMQCellIndicatorDiameter)];
    self.sendingIndicatorFrame = CGRectMake(self.bubbleImageFrame.origin.x-kMQCellBubbleToIndicatorSpacing-indicatorView.frame.size.width, self.bubbleImageFrame.origin.y+self.bubbleImageFrame.size.height/2-indicatorView.frame.size.height/2, indicatorView.frame.size.width, indicatorView.frame.size.height);
    
    //发送失败的图片frame
    UIImage *failureImage = [MQChatViewConfig sharedConfig].messageSendFailureImage;
    self.sendFailureFrame = CGRectMake(self.bubbleImageFrame.origin.x-kMQCellBubbleToIndicatorSpacing-failureImage.size.width, self.bubbleImageFrame.origin.y+self.bubbleImageFrame.size.height/2-failureImage.size.height/2, failureImage.size.width, failureImage.size.height);
    
    //计算cell的高度
    self.cellHeight = self.bubbleImageFrame.origin.y + self.bubbleImageFrame.size.height + kMQCellAvatarToVerticalEdgeSpacing;

}


#pragma MQCellModelProtocol
- (CGFloat)getCellHeight {
    return self.cellHeight;
}

/**
 *  通过重用的名字初始化cell
 *  @return 初始化了一个cell
 */
- (MQChatBaseCell *)getCellWithReuseIdentifier:(NSString *)cellReuseIdentifer {
    return [[MQImageMessageCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellReuseIdentifer];
}

- (NSDate *)getCellDate {
    return self.date;
}

- (BOOL)isServiceRelatedCell {
    return true;
}

- (NSString *)getCellMessageId {
    return self.messageId;
}

@end
