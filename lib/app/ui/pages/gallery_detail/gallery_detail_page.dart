import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:i_iwara/app/routes/app_routes.dart';
import 'package:i_iwara/app/services/app_service.dart';
import 'package:i_iwara/app/services/user_service.dart';
import 'package:i_iwara/app/ui/pages/comment/widgets/comment_input_dialog.dart';
import 'package:i_iwara/app/ui/pages/gallery_detail/widgets/image_model_detail_content_widget.dart';
import 'package:i_iwara/app/ui/pages/video_detail/widgets/media_tile_list_loading_widget.dart';
import 'package:i_iwara/app/ui/pages/video_detail/widgets/video_detail_info_skeleton_widget.dart';
import 'package:i_iwara/app/ui/widgets/MDToastWidget.dart';
import 'package:i_iwara/app/ui/widgets/empty_widget.dart';
import 'package:i_iwara/utils/widget_extensions.dart';
import 'package:oktoast/oktoast.dart';

import '../../../../common/enums/media_enums.dart';
import '../../../../utils/logger_utils.dart';
import '../../widgets/error_widget.dart';
import '../comment/controllers/comment_controller.dart';
import '../comment/widgets/comment_entry_area_widget.dart';
import '../comment/widgets/comment_section_widget.dart';
import '../popular_media_list/widgets/image_model_tile_list_item_widget.dart';
import '../video_detail/controllers/related_media_controller.dart';
import 'controllers/gallery_detail_controller.dart';
import 'package:i_iwara/i18n/strings.g.dart' as slang;
import 'widgets/gallery_image_scroller_widget.dart';

class GalleryDetailPage extends StatefulWidget {
  final String imageModelId;

  const GalleryDetailPage({super.key, required this.imageModelId});

  @override
  _GalleryDetailPageState createState() => _GalleryDetailPageState();
}

class _GalleryDetailPageState extends State<GalleryDetailPage> {
  late String imageModelId;
  late GalleryDetailController detailController;
  late CommentController commentController;
  late RelatedMediasController relatedMediasController;
  late String uniqueTag;

  // 分配图库详情与附列表的宽度
  final double sideColumnMinWidth = 400.0; // 右侧固定宽度
  final double leftColumnMinWidth = 600.0; // 左侧内容的最小期望宽度，用于判断是否宽屏

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  // dispose
  @override
  void dispose() {
    Get.delete<GalleryDetailController>(tag: uniqueTag);
    Get.delete<CommentController>(tag: uniqueTag);
    Get.delete<RelatedMediasController>(tag: uniqueTag);

    LogUtils.d('图库ID: $imageModelId 已销毁', 'GalleryDetailPage');
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    imageModelId = widget.imageModelId;
    uniqueTag = UniqueKey().toString();

    if (imageModelId.isEmpty) {
      return;
    }
    LogUtils.d('图库ID: $imageModelId 初始化状态, $uniqueTag', 'GalleryDetailPage');

    // 初始化控制器
    detailController = Get.put(
      GalleryDetailController(imageModelId),
      tag: uniqueTag,
    );

    commentController = Get.put(
      CommentController(id: imageModelId, type: CommentType.image),
      tag: uniqueTag,
    );

    relatedMediasController = Get.put(
      RelatedMediasController(
          mediaId: imageModelId, mediaType: MediaType.IMAGE),
      tag: uniqueTag,
    );
  }

  // 构建头部区域
  Widget _buildHeader(BuildContext context, double paddingTop) {
    return AppBar(
        backgroundColor: Colors.transparent,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                detailController.imageModelInfo.value?.title ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () {
                AppService appService = Get.find();
                int currentIndex = appService.currentIndex;
                final routes = [
                  Routes.POPULAR_VIDEOS,
                  Routes.GALLERY,
                  Routes.SUBSCRIPTIONS,
                ];
                AppService.homeNavigatorKey.currentState!
                    .pushNamedAndRemoveUntil(
                        routes[currentIndex], (route) => false);
              },
            ),
          ],
        ));
  }

  // 计算是否需要分两列
  bool _shouldUseWideScreenLayout(double screenHeight, double screenWidth) {
    // 如果屏幕宽度足够容纳左侧最小宽度和右侧固定宽度，则使用宽屏布局
    return screenWidth >= leftColumnMinWidth + sideColumnMinWidth;
  }

  void showCommentModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.2,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // 顶部标题栏
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Text(
                        slang.t.common.commentList,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      // 添加评论按钮
                      TextButton.icon(
                        onPressed: () {
                          Get.dialog(
                            CommentInputDialog(
                              title: slang.t.common.sendComment,
                              submitText: slang.t.common.send,
                              onSubmit: (text) async {
                                if (text.trim().isEmpty) {
                                  showToastWidget(
                                      MDToastWidget(
                                          message: slang
                                              .t.errors.commentCanNotBeEmpty,
                                          type: MDToastType.error),
                                      position: ToastPosition.bottom);
                                  return;
                                }
                                final UserService userService = Get.find();
                                if (!userService.isLogin) {
                                  showToastWidget(
                                      MDToastWidget(
                                          message:
                                              slang.t.errors.pleaseLoginFirst,
                                          type: MDToastType.error),
                                      position: ToastPosition.bottom);
                                  Get.toNamed(Routes.LOGIN);
                                  return;
                                }
                                await commentController.postComment(text);
                              },
                            ),
                            barrierDismissible: true,
                          );
                        },
                        icon: const Icon(Icons.add_comment),
                        label: Text(slang.t.common.sendComment),
                      ),
                      // 关闭按钮
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // 评论列表
                Expanded(
                  child: Obx(() => CommentSection(
                      controller: commentController,
                      authorUserId:
                          detailController.imageModelInfo.value?.user?.id)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = slang.Translations.of(context);
    if (imageModelId.isEmpty) {
      return CommonErrorWidget(
        text: t.errors.invalidGalleryId,
        children: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(t.common.back),
          ),
        ],
      );
    }

    // 获取屏幕尺寸和内边距
    Size screenSize = MediaQuery.sizeOf(context);
    double paddingTop = MediaQuery.paddingOf(context).top;
    double screenHeight = screenSize.height;
    double screenWidth = screenSize.width;

    // 判断是否使用宽屏布局 (移出 Obx)
    bool isWide = _shouldUseWideScreenLayout(screenHeight, screenWidth);

    // 计算图片滚动区域的最大高度 (移出 Obx)
    final double imageScrollerMaxHeight = screenHeight * 0.55;

    // 只在构建时打印一次日志 (移出 Obx)
    LogUtils.d('[DEBUG] 是否使用宽屏布局: $isWide', 'GalleryDetailPage');

    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event.logicalKey == LogicalKeyboardKey.escape) {
          if (detailController.isCommentSheetVisible.value) {
            detailController.isCommentSheetVisible.toggle();
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: Scaffold(
        body: Obx(() {
          if (detailController.errorMessage.value != null) {
            return CommonErrorWidget(
              text: detailController.errorMessage.value ??
                  t.errors.errorWhileLoadingGallery,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(t.common.back),
                ),
              ],
            );
          }

          if (isWide) {
            // 宽屏布局
            if (detailController.isImageModelInfoLoading.value) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左侧图库详情骨架
                  Expanded(
                    child: MediaDetailInfoSkeletonWidget(
                      mediaPlaceholderHeight: imageScrollerMaxHeight,
                    ),
                  ),
                  // 右侧列表骨架
                  SizedBox(
                      width: sideColumnMinWidth,
                      child: const MediaTileListSkeletonWidget()),
                ],
              );
            }

            if (detailController.imageModelInfo.value == null) {
              return const MyEmptyWidget();
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column (Scrollable Content)
                Expanded(
                  child: SingleChildScrollView(
                    // 左侧内容整体可滚动
                    physics: detailController.isHoveringHorizontalList.value
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. Header (reusing or new widget)
                        _buildHeader(context, paddingTop),
                        // 2. Image Scroller with Max Height
                        GalleryImageScrollerWidget(
                          controller: detailController,
                          maxHeight: imageScrollerMaxHeight,
                        ),
                        // 3. Gallery Details
                        ImageModelDetailContent(
                          controller: detailController,
                        ),
                        // 4. Comment Entry Button
                        CommentEntryAreaButtonWidget(
                          commentController: commentController,
                          onClickButton: () => showCommentModal(context),
                        ).paddingVertical(16),
                        // 5. Safe Area Bottom Padding
                        const SafeArea(child: SizedBox.shrink()),
                      ],
                    ),
                  ),
                ),
                // Right Column (Fixed Width, Scrollable List)
                SizedBox(
                  // 右侧固定宽度
                  width: sideColumnMinWidth,
                  child: SingleChildScrollView(
                    // 右侧列表独立滚动
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(height: paddingTop + 16), // Adjust top padding
                        // Author's other galleries title
                        Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(t.galleryDetail.authorOtherGalleries,
                                style: const TextStyle(fontSize: 18))),
                        const SizedBox(height: 16),
                        // Author's other galleries list (logic remains)
                        if (detailController
                                    .otherAuthorzImageModelsController !=
                                null &&
                            detailController.otherAuthorzImageModelsController!
                                .isLoading.value)
                          const MediaTileListSkeletonWidget()
                        else if (detailController
                            .otherAuthorzImageModelsController!
                            .imageModels
                            .isEmpty)
                          const MyEmptyWidget()
                        else
                          ...detailController
                              .otherAuthorzImageModelsController!.imageModels
                              .map((imageModel) => ImageModelTileListItem(
                                  imageModel: imageModel))
                              .toList(),
                        const SizedBox(height: 16),
                        // Related galleries title
                        Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(t.galleryDetail.relatedGalleries,
                                style: const TextStyle(fontSize: 18))),
                        const SizedBox(height: 16),
                        // Related galleries list (logic remains)
                        if (relatedMediasController.isLoading.value)
                          const MediaTileListSkeletonWidget()
                        else if (relatedMediasController.imageModels.isEmpty)
                          const MyEmptyWidget()
                        else
                          ...relatedMediasController.imageModels
                              .map((imageModel) => ImageModelTileListItem(
                                  imageModel: imageModel))
                              .toList(),
                        const SafeArea(
                            child:
                                SizedBox.shrink()), // Safe area bottom padding
                      ],
                    ),
                  ),
                )
              ],
            );
          } else {
            // Narrow Screen Layout
            // --- Loading State --- (调整骨架)
            if (detailController.isImageModelInfoLoading.value) {
              return MediaDetailInfoSkeletonWidget(
                mediaPlaceholderHeight: imageScrollerMaxHeight,
              );
            }

            // --- Empty State --- (保持不变)
            if (detailController.imageModelInfo.value == null) {
              return const MyEmptyWidget();
            }

            // --- Loaded State --- (调整布局)
            return SingleChildScrollView(
              // 整个页面可滚动
              physics: detailController.isHoveringHorizontalList.value
                  ? const NeverScrollableScrollPhysics()
                  : null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Header
                  _buildHeader(context, paddingTop),
                  // 2. Image Scroller with Max Height
                  GalleryImageScrollerWidget(
                    controller: detailController,
                    maxHeight: imageScrollerMaxHeight,
                  ),
                  // 3. Gallery Details
                  ImageModelDetailContent(
                    controller: detailController,
                  ),
                  // 4. Comment Entry Area Button
                  Container(
                      padding: const EdgeInsets.all(16),
                      child: CommentEntryAreaButtonWidget(
                        commentController: commentController,
                        onClickButton: () => showCommentModal(context),
                      ).paddingVertical(16)),
                  // 5. Author's Other Galleries Title
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(t.galleryDetail.authorOtherGalleries,
                          style: const TextStyle(fontSize: 18))),
                  // 6. Author's Other Galleries List (logic remains)
                  if (detailController.otherAuthorzImageModelsController !=
                          null &&
                      detailController
                          .otherAuthorzImageModelsController!.isLoading.value)
                    const MediaTileListSkeletonWidget()
                  else if (detailController
                      .otherAuthorzImageModelsController!.imageModels.isEmpty)
                    const MyEmptyWidget()
                  else
                    ...detailController
                        .otherAuthorzImageModelsController!.imageModels
                        .map((imageModel) =>
                            ImageModelTileListItem(imageModel: imageModel))
                        .toList(),
                  // 7. Related Galleries Title
                  const SizedBox(height: 16),
                  Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(t.galleryDetail.relatedGalleries,
                          style: const TextStyle(fontSize: 18))),
                  const SizedBox(height: 16),
                  // 8. Related Galleries List (logic remains)
                  if (relatedMediasController.isLoading.value)
                    const MediaTileListSkeletonWidget()
                  else if (relatedMediasController.imageModels.isEmpty)
                    const MyEmptyWidget()
                  else
                    ...relatedMediasController.imageModels
                        .map((imageModel) =>
                            ImageModelTileListItem(imageModel: imageModel))
                        .toList(),
                  // 9. Safe Area Bottom Padding
                  const SafeArea(child: SizedBox.shrink()),
                ],
              ),
            );
          }
        }),
      ),
    );
  }
}
