import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:get/get.dart';
import 'package:i_iwara/app/services/app_service.dart';
import 'package:i_iwara/app/services/config_service.dart';
import 'package:i_iwara/app/ui/pages/video_detail/widgets/player/rapple_painter.dart';
import 'package:i_iwara/utils/common_utils.dart';
import 'package:i_iwara/utils/logger_utils.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:vibration/vibration.dart';

import '../video_rating_animation.dart';
import 'bottom_toolbar_widget.dart';
import 'gesture_area_widget.dart';
import 'top_toolbar_widget.dart';
import '../../controllers/my_video_state_controller.dart';
import '../../../../../../i18n/strings.g.dart' as slang;

class MyVideoScreen extends StatefulWidget {
  final bool isFullScreen;
  final MyVideoStateController myVideoStateController;

  const MyVideoScreen({
    super.key,
    this.isFullScreen = false,
    required this.myVideoStateController,
  });

  @override
  State<MyVideoScreen> createState() => _MyVideoScreenState();
}

class _MyVideoScreenState extends State<MyVideoScreen>
    with TickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  final ConfigService _configService = Get.find();
  final AppService _appService = Get.find();

  Timer? _autoHideTimer;
  Timer? _volumeInfoTimer; // 添加音量提示计时器
  DateTime? _lastLeftKeyPressTime;
  DateTime? _lastRightKeyPressTime;
  static const Duration _debounceTime = Duration(milliseconds: 300);

  late AnimationController _leftRippleController1;
  late AnimationController _leftRippleController2;
  bool _isLeftRippleActive1 = false;
  bool _isLeftRippleActive2 = false;

  late AnimationController _rightRippleController1;
  late AnimationController _rightRippleController2;
  bool _isRightRippleActive1 = false;
  bool _isRightRippleActive2 = false;

  // 控制InfoMessage的显示与淡入淡出动画
  late AnimationController _infoMessageFadeController;
  late Animation<double> _infoMessageOpacity;
  bool isSlidingBrightnessZone = false; // 是否在滑动亮度区域
  bool isSlidingVolumeZone = false; // 是否在滑动音量区域
  bool isLongPressing = false; // 是否在长按

  double? _horizontalDragStartX;
  Duration? _horizontalDragStartPosition;
  static const int MAX_SEEK_SECONDS = 90;

  @override
  void initState() {
    LogUtils.d("[${widget.isFullScreen ? '全屏' : '内嵌'} 初始化]", 'MyVideoScreen');
    super.initState();
    // 如果是全屏状态
    if (widget.isFullScreen) {
      _appService.hideSystemUI();
      // 继续播放
      // 如果当前是非全屏，则继续播放
      if (!widget.myVideoStateController.isFullscreen.value) {
        widget.myVideoStateController.player.play();
      }
      // 确保在全屏状态下获取焦点
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }

    _initializeAnimationControllers();
    _initializeInfoMessageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 在依赖变化时重新请求焦点
    _focusNode.requestFocus();
  }

  void _initializeAnimationControllers() {
    _leftRippleController1 = _createAnimationController();
    _leftRippleController2 = _createAnimationController();
    _rightRippleController1 = _createAnimationController();
    _rightRippleController2 = _createAnimationController();
  }

  AnimationController _createAnimationController({int duration = 800}) {
    return AnimationController(
      duration: Duration(milliseconds: duration),
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _isLeftRippleActive1 = false;
            _isLeftRippleActive2 = false;
            _isRightRippleActive1 = false;
            _isRightRippleActive2 = false;
          });
        }
      });
  }

  void _initializeInfoMessageController() {
    _infoMessageFadeController = AnimationController(
      duration: const Duration(milliseconds: 0),
      vsync: this,
    );

    _infoMessageOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _infoMessageFadeController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    if (widget.isFullScreen) {
      // 恢复系统UI和竖屏模式
      _appService.showSystemUI();
      // 恢复播放
      // widget.myVideoStateController.player.play();
    }
    _focusNode.dispose();
    _leftRippleController1.dispose();
    _leftRippleController2.dispose();
    _rightRippleController1.dispose();
    _rightRippleController2.dispose();
    _infoMessageFadeController.dispose();
    _autoHideTimer?.cancel();
    _volumeInfoTimer?.cancel(); // 取消音量提示计时器
    super.dispose();
  }

  /// 处理左键按下
  void _handleLeftKeyPress() {
    // 检查是否需要防抖
    if (_lastLeftKeyPressTime != null) {
      final timeDiff = DateTime.now().difference(_lastLeftKeyPressTime!);
      if (timeDiff < _debounceTime) {
        // 如果距离上次按键时间太短，则忽略此次按键
        return;
      }
    }
    
    // 更新最后按键时间
    _lastLeftKeyPressTime = DateTime.now();
    
    // 触发后退效果
    _triggerLeftRipple();
  }

  /// 处理右键按下
  void _handleRightKeyPress() {
    // 检查是否需要防抖
    if (_lastRightKeyPressTime != null) {
      final timeDiff = DateTime.now().difference(_lastRightKeyPressTime!);
      if (timeDiff < _debounceTime) {
        // 如果距离上次按键时间太短，则忽略此次按键
        return;
      }
    }
    
    // 更新最后按键时间
    _lastRightKeyPressTime = DateTime.now();
    
    // 触发快进效果
    _triggerRightRipple();
  }

  void _triggerLeftRipple() {
    if (_isLeftRippleActive1 || _isLeftRippleActive2) return;
    setState(() {
      _isLeftRippleActive1 = true;
      _isLeftRippleActive2 = false;
    });
    _leftRippleController1.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _isLeftRippleActive2 = true;
        });
        _leftRippleController2.forward(from: 0);
      }
    });

    // 获取当前的时间
    Duration currentPosition =
        widget.myVideoStateController.currentPosition.value;
    int seconds = _configService[ConfigService.REWIND_SECONDS_KEY] as int;
    if (currentPosition.inSeconds - seconds > 0) {
      currentPosition = Duration(seconds: currentPosition.inSeconds - seconds);
    } else {
      currentPosition = Duration.zero;
    }

    widget.myVideoStateController.player.seek(currentPosition);
  }

  void _triggerRightRipple() {
    if (_isRightRippleActive1 || _isRightRippleActive2) return;
    setState(() {
      _isRightRippleActive1 = true;
      _isRightRippleActive2 = false;
    });
    _rightRippleController1.forward(from: 0);
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _isRightRippleActive2 = true;
        });
        _rightRippleController2.forward(from: 0);
      }
    });

    // 获取当前的时间
    Duration currentPosition =
        widget.myVideoStateController.currentPosition.value;
    Duration totalDuration = widget.myVideoStateController.totalDuration.value;
    int seconds = _configService[ConfigService.FAST_FORWARD_SECONDS_KEY] as int;
    if (currentPosition.inSeconds + seconds < totalDuration.inSeconds) {
      currentPosition = Duration(seconds: currentPosition.inSeconds + seconds);
    } else {
      currentPosition = totalDuration;
    }
    widget.myVideoStateController.player.seek(currentPosition);
  }

  // 单击事件
  void _onTap() {
    widget.myVideoStateController.toggleToolbars();
  }

  // 添加显示音量提示的方法
  void _showVolumeInfo() {
    // 取消之前的计时器
    _volumeInfoTimer?.cancel();
    
    setState(() {
      isSlidingVolumeZone = true;
    });
    _infoMessageFadeController.forward();
    
    // 设置新的计时器
    _volumeInfoTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        _infoMessageFadeController.reverse().whenComplete(() {
          setState(() {
            isSlidingVolumeZone = false;
          });
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (widget.isFullScreen) {
          await defaultExitNativeFullscreen();
          widget.myVideoStateController.isFullscreen.value = false;
        }
      },
      child: Scaffold(
        backgroundColor: _configService[ConfigService.THEATER_MODE_KEY] 
          ? Colors.black 
          : const Color(0xFF000000),
        body: Stack(
          children: [
            // 剧院模式背景 - 移到最外层
            Obx(() => _configService[ConfigService.THEATER_MODE_KEY] 
              ? Positioned.fill(
                  child: Image.network(
                    widget.myVideoStateController.videoInfo.value?.thumbnailUrl ?? '',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.black,
                    ),
                  ),
                )
              : const SizedBox.shrink()),
            // 模糊效果 - 移到最外层
            Obx(() => _configService[ConfigService.THEATER_MODE_KEY]
              ? Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                    ),
                  ),
                )
              : const SizedBox.shrink()),
            // 主要内容
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                // paddingTop
                double paddingTop = MediaQuery.paddingOf(context).top;
                // 获取视频部分的尺寸
                final screenSize = Size(constraints.maxWidth, constraints.maxHeight);
                // 根据屏幕宽度计算图标大小
                final playPauseIconSize = (screenSize.width * 0.15).clamp(
                  40.0, // 最小尺寸
                  100.0, // 最大尺寸
                );

                // 缓冲动画稍微小一点，使用图标尺寸的80%
                final bufferingSize = playPauseIconSize * 0.8;

                final maxRadius = (screenSize.height - paddingTop) * 2 / 3;

                return FocusScope(
                  autofocus: true,
                  canRequestFocus: true,
                  child: KeyboardListener(
                    focusNode: _focusNode,
                    onKeyEvent: (KeyEvent event) {
                      if (event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                          _handleLeftKeyPress();
                        } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                          _handleRightKeyPress();
                        } else if (event.logicalKey == LogicalKeyboardKey.space) {
                          if (widget.myVideoStateController.videoPlaying.value) {
                            widget.myVideoStateController.player.pause();
                          } else {
                            widget.myVideoStateController.player.play();
                          }
                        } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                          // 获取当前音量
                          double currentVolume = _configService[ConfigService.VOLUME_KEY];
                          // 增加音量，每次增加0.1，最大为1.0
                          double newVolume = (currentVolume + 0.1).clamp(0.0, 1.0);
                          widget.myVideoStateController.setVolume(newVolume);
                          // 显示音量提示
                          _showVolumeInfo();
                        } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                          // 获取当前音量
                          double currentVolume = _configService[ConfigService.VOLUME_KEY];
                          // 减少音量，每次减少0.1，最小为0.0
                          double newVolume = (currentVolume - 0.1).clamp(0.0, 1.0);
                          widget.myVideoStateController.setVolume(newVolume);
                          // 显示音量提示
                          _showVolumeInfo();
                        }
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.only(top: paddingTop),
                      child: Stack(
                        children: [
                          // 视频播放区域
                          _buildVideoPlayer(),
                          // 手势监听
                          ..._buildGestureAreas(screenSize),
                          // 工具栏
                          ..._buildToolbars(),
                          // 左右的双击波纹动画
                          _buildRippleEffects(screenSize, maxRadius),
                          // loading、暂停和播放等居中控件
                          _buildVideoControlOverlay(playPauseIconSize, bufferingSize),
                          // InfoMessage
                          _buildInfoMessage(),
                          _buildSeekPreview(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return Center(
      child: Obx(() => AspectRatio(
            aspectRatio: widget.myVideoStateController.aspectRatio.value,
            child: Video(
              controller: widget.myVideoStateController.videoController,
              controls: null,
            ),
          )),
    );
  }

  List<Widget> _buildGestureAreas(Size screenSize) {
    return [
      Obx(() => Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: screenSize.width *
                _configService[
                    ConfigService.VIDEO_LEFT_AND_RIGHT_CONTROL_AREA_RATIO],
            child: GestureArea(
              setLongPressing: _setLongPressing,
              onTap: _onTap,
              region: GestureRegion.left,
              myVideoStateController: widget.myVideoStateController,
              onDoubleTapLeft: _triggerLeftRipple,
              screenSize: screenSize,
              onHorizontalDragStart: (details) {
                _horizontalDragStartX = details.localPosition.dx;
                _horizontalDragStartPosition = widget.myVideoStateController.currentPosition.value;
                widget.myVideoStateController.setInteracting(true);
                widget.myVideoStateController.showSeekPreview(true);
              },
              onHorizontalDragUpdate: (details) {
                if (_horizontalDragStartX == null || _horizontalDragStartPosition == null) return;
                
                double dragDistance = details.localPosition.dx - _horizontalDragStartX!;
                double ratio = dragDistance / screenSize.width;
                
                int offsetSeconds = (ratio * MAX_SEEK_SECONDS).round();
                
                Duration targetPosition = Duration(
                  seconds: (_horizontalDragStartPosition!.inSeconds + offsetSeconds)
                      .clamp(0, widget.myVideoStateController.totalDuration.value.inSeconds)
                );
                
                widget.myVideoStateController.updateSeekPreview(targetPosition);
              },
              onHorizontalDragEnd: (details) {
                if (_horizontalDragStartPosition != null) {
                  Duration targetPosition = widget.myVideoStateController.previewPosition.value;
                  widget.myVideoStateController.player.seek(targetPosition);
                }
                
                _horizontalDragStartX = null;
                _horizontalDragStartPosition = null;
                widget.myVideoStateController.setInteracting(false);
                widget.myVideoStateController.showSeekPreview(false);
              },
            ),
          )),
      Obx(() => Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: screenSize.width *
                _configService[
                    ConfigService.VIDEO_LEFT_AND_RIGHT_CONTROL_AREA_RATIO],
            child: GestureArea(
              setLongPressing: _setLongPressing,
              onTap: _onTap,
              region: GestureRegion.right,
              myVideoStateController: widget.myVideoStateController,
              onDoubleTapRight: _triggerRightRipple,
              screenSize: screenSize,
              onVolumeChange: (volume) => widget.myVideoStateController.setVolume(volume, save: false),
              onHorizontalDragStart: (details) {
                _horizontalDragStartX = details.localPosition.dx;
                _horizontalDragStartPosition = widget.myVideoStateController.currentPosition.value;
                widget.myVideoStateController.setInteracting(true);
                widget.myVideoStateController.showSeekPreview(true);
              },
              onHorizontalDragUpdate: (details) {
                if (_horizontalDragStartX == null || _horizontalDragStartPosition == null) return;
                
                double dragDistance = details.localPosition.dx - _horizontalDragStartX!;
                double ratio = dragDistance / screenSize.width;
                
                int offsetSeconds = (ratio * MAX_SEEK_SECONDS).round();
                
                Duration targetPosition = Duration(
                  seconds: (_horizontalDragStartPosition!.inSeconds + offsetSeconds)
                      .clamp(0, widget.myVideoStateController.totalDuration.value.inSeconds)
                );
                
                widget.myVideoStateController.updateSeekPreview(targetPosition);
              },
              onHorizontalDragEnd: (details) {
                if (_horizontalDragStartPosition != null) {
                  Duration targetPosition = widget.myVideoStateController.previewPosition.value;
                  widget.myVideoStateController.player.seek(targetPosition);
                }
                
                _horizontalDragStartX = null;
                _horizontalDragStartPosition = null;
                widget.myVideoStateController.setInteracting(false);
                widget.myVideoStateController.showSeekPreview(false);
              },
            ),
          )),
      Obx(() {
        double ratio = _configService[
            ConfigService.VIDEO_LEFT_AND_RIGHT_CONTROL_AREA_RATIO] as double;
        double position = screenSize.width * ratio;
        return Positioned(
          left: position,
          right: position,
          top: 0,
          bottom: 0,
          child: GestureArea(
            setLongPressing: _setLongPressing,
            onTap: _onTap,
            region: GestureRegion.center,
            myVideoStateController: widget.myVideoStateController,
            screenSize: screenSize,
            onHorizontalDragStart: (details) {
              _horizontalDragStartX = details.localPosition.dx;
              _horizontalDragStartPosition = widget.myVideoStateController.currentPosition.value;
              widget.myVideoStateController.setInteracting(true);
              widget.myVideoStateController.showSeekPreview(true);
            },
            onHorizontalDragUpdate: (details) {
              if (_horizontalDragStartX == null || _horizontalDragStartPosition == null) return;
              
              double dragDistance = details.localPosition.dx - _horizontalDragStartX!;
              double ratio = dragDistance / screenSize.width;
              
              int offsetSeconds = (ratio * MAX_SEEK_SECONDS).round();
              
              Duration targetPosition = Duration(
                seconds: (_horizontalDragStartPosition!.inSeconds + offsetSeconds)
                    .clamp(0, widget.myVideoStateController.totalDuration.value.inSeconds)
              );
              
              widget.myVideoStateController.updateSeekPreview(targetPosition);
            },
            onHorizontalDragEnd: (details) {
              if (_horizontalDragStartPosition != null) {
                Duration targetPosition = widget.myVideoStateController.previewPosition.value;
                widget.myVideoStateController.player.seek(targetPosition);
              }
              
              _horizontalDragStartX = null;
              _horizontalDragStartPosition = null;
              widget.myVideoStateController.setInteracting(false);
              widget.myVideoStateController.showSeekPreview(false);
            },
          ),
        );
      }),
    ];
  }

  List<Widget> _buildToolbars() {
    return [
      Positioned(
        top: -MediaQuery.paddingOf(context).top,
        left: 0,
        right: 0,
        child: TopToolbar(
            myVideoStateController: widget.myVideoStateController,
            currentScreenIsFullScreen: widget.isFullScreen),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: BottomToolbar(
            myVideoStateController: widget.myVideoStateController,
            currentScreenIsFullScreen: widget.isFullScreen),
      ),
    ];
  }

  Widget _buildRippleEffects(Size screenSize, double maxRadius) {
    return Positioned.fill(
      child: Stack(
        children: [
          if (_isLeftRippleActive1)
            _buildRipple(_leftRippleController1,
                Offset(0, screenSize.height / 2), maxRadius),
          if (_isLeftRippleActive2)
            _buildRipple(_leftRippleController2,
                Offset(0, screenSize.height / 2), maxRadius),
          if (_isRightRippleActive1)
            _buildRipple(_rightRippleController1,
                Offset(screenSize.width, screenSize.height / 2), maxRadius),
          if (_isRightRippleActive2)
            _buildRipple(_rightRippleController2,
                Offset(screenSize.width, screenSize.height / 2), maxRadius),
        ],
      ),
    );
  }

  Widget _buildRipple(AnimationController controller,
      Offset origin, double maxRadius) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return CustomPaint(
          painter: RipplePainter(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            animationValue: controller.value,
            origin: origin,
            maxRadius: maxRadius,
          ),
        );
      },
    );
  }

  Widget _buildVideoControlOverlay(
      double playPauseIconSize, double bufferingSize) {
    return Obx(
      () => Positioned.fill(
        child: widget.myVideoStateController.videoBuffering.value
            ? Center(
                child: _buildBufferingAnimation(
                    widget.myVideoStateController, bufferingSize),
              )
            : Center(
                child: _buildPlayPauseIcon(
                    widget.myVideoStateController, playPauseIconSize),
              ),
      ),
    );
  }

  Widget _buildPlayPauseIcon(
      MyVideoStateController myVideoStateController, double size) {
    return Obx(() => AnimatedOpacity(
          opacity: myVideoStateController.videoPlaying.value ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  // 添加震动反馈
                  if (await Vibration.hasVibrator() ?? false) {
                    await Vibration.vibrate(duration: 50);
                  }
                  
                  myVideoStateController.videoPlaying.value
                      ? myVideoStateController.player.pause()
                      : myVideoStateController.player.play();
                },
                customBorder: const CircleBorder(),
                child: AnimatedScale(
                  scale: myVideoStateController.videoPlaying.value ? 1.0 : 0.9,
                  duration: const Duration(milliseconds: 150),
                  child: Icon(
                    myVideoStateController.videoPlaying.value
                        ? Icons.pause
                        : Icons.play_arrow,
                    color: Colors.white,
                    size: size * 0.6, // 图标大小为容器的60%
                    shadows: [
                      Shadow(
                        blurRadius: 8.0,
                        color: Colors.black.withOpacity(0.5),
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ));
  }

  /// 构建缓冲动画，尺寸自适应
  Widget _buildBufferingAnimation(
      MyVideoStateController myVideoStateController, double size) {
    return Obx(() => myVideoStateController.videoBuffering.value
        ? Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Padding(
              padding: EdgeInsets.all(size * 0.2), // 内边距为尺寸的20%
              child: CircularProgressIndicator(
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: size * 0.08, // 线条宽度为尺寸的8%
              ).animate(onPlay: (controller) => controller.repeat()).rotate(
                    duration: const Duration(milliseconds: 1000),
                    curve: Curves.linear,
                  ),
            ),
          )
        : const SizedBox.shrink());
  }

  void _setLongPressing(LongPressType? longPressType, bool value) async {
    if (value) {
      // 根据长按类型更新UI
      switch (longPressType) {
        case LongPressType.brightness:
          setState(() {
            isSlidingBrightnessZone = true;
            isSlidingVolumeZone = false;
            isLongPressing = false;
          });
          _infoMessageFadeController.forward();
          break;
        case LongPressType.volume:
          setState(() {
            isSlidingVolumeZone = true;
            isSlidingBrightnessZone = false;
            isLongPressing = false;
          });
          _infoMessageFadeController.forward();
          break;
        case LongPressType.normal:
          setState(() {
            isLongPressing = true;
            isSlidingBrightnessZone = false;
            isSlidingVolumeZone = false;
          });
          widget.myVideoStateController
              .setLongPressPlaybackSpeedByConfiguration();
          _infoMessageFadeController.forward();
          break;
        default:
          _infoMessageFadeController.reverse();
          break;
      }
    } else {
      // 当长按结束时，清除提示并反转动画
      _infoMessageFadeController.reverse().whenComplete(() {
        setState(() {
          isLongPressing = false;
          isSlidingBrightnessZone = false;
          isSlidingVolumeZone = false;
        });
      });
    }
  }

  // 快进的消息提示
  Widget _buildInfoMessage() {
    return Positioned(
      top: 50,
      left: 0,
      right: 0,
      child: Center(
        child: _buildInfoContent(),
      ),
    );
  }

  Widget _buildInfoContent() {
    if (isSlidingVolumeZone) {
      return _buildFadeTransition(
        child: _buildVolumeInfoMessage(),
      );
    } else if (isSlidingBrightnessZone) {
      return _buildFadeTransition(
        child: _buildBrightnessInfoMessage(),
      );
    } else if (isLongPressing) {
      return _buildFadeTransition(
        child: _buildPlaybackSpeedInfoMessage(),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildFadeTransition({required Widget child}) {
    return FadeTransition(
      opacity: _infoMessageOpacity,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      ),
    );
  }

  Widget _buildPlaybackSpeedInfoMessage() {
    return Obx(() {
      double rate =
          _configService[ConfigService.LONG_PRESS_PLAYBACK_SPEED_KEY] as double;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.speed, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            slang.t.videoDetail.playbackSpeedIng(rate: rate),
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      );
    });
  }

  Widget _buildBrightnessInfoMessage() {
    return Obx(() {
      var curBrightness =
          _configService[ConfigService.BRIGHTNESS_KEY] as double;
      IconData brightnessIcon;
      String brightnessText;

      if (curBrightness <= 0.0) {
        brightnessIcon = Icons.brightness_3_rounded;
        brightnessText = slang.t.videoDetail.brightnessLowest;
      } else if (curBrightness > 0.0 && curBrightness <= 0.2) {
        brightnessIcon = Icons.brightness_2_rounded;
        brightnessText =
            '${slang.t.videoDetail.brightness}: ${(curBrightness * 100).toInt()}%';
      } else if (curBrightness > 0.2 && curBrightness <= 0.5) {
        brightnessIcon = Icons.brightness_5_rounded;
        brightnessText =
            '${slang.t.videoDetail.brightness}: ${(curBrightness * 100).toInt()}%';
      } else if (curBrightness > 0.5 && curBrightness <= 0.8) {
        brightnessIcon = Icons.brightness_4_rounded;
        brightnessText =
            '${slang.t.videoDetail.brightness}: ${(curBrightness * 100).toInt()}%';
      } else if (curBrightness > 0.8 && curBrightness <= 1.0) {
        brightnessIcon = Icons.brightness_7_rounded;
        brightnessText =
            '${slang.t.videoDetail.brightness}: ${(curBrightness * 100).toInt()}%';
      } else {
        // 处理意外情况，例如亮度超过范围
        brightnessIcon = Icons.brightness_3_rounded;
        brightnessText =
            '${slang.t.videoDetail.brightness}: ${(curBrightness * 100).toInt()}%';
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(brightnessIcon, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            brightnessText,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      );
    });
  }

  Widget _buildVolumeInfoMessage() {
    return Obx(() {
      var curVolume = _configService[ConfigService.VOLUME_KEY] as double;
      IconData volumeIcon;
      String volumeText;

      if (curVolume == 0.0) {
        volumeIcon = Icons.volume_off;
        volumeText = slang.t.videoDetail.volumeMuted;
      } else if (curVolume > 0.0 && curVolume <= 0.3) {
        volumeIcon = Icons.volume_down;
        volumeText =
            '${slang.t.videoDetail.volume}: ${(curVolume * 100).toInt()}%';
      } else if (curVolume > 0.3 && curVolume <= 1.0) {
        volumeIcon = Icons.volume_up;
        volumeText =
            '${slang.t.videoDetail.volume}: ${(curVolume * 100).toInt()}%';
      } else {
        // 处理意外情况，例如音量超过范围
        volumeIcon = Icons.volume_off;
        volumeText =
            '${slang.t.videoDetail.volume}: ${(curVolume * 100).toInt()}%';
      }

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(volumeIcon, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            volumeText,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      );
    });
  }

 Widget _buildSeekPreview() {
    return Obx(() {
      if (!widget.myVideoStateController.isSeekPreviewVisible.value) {
        return const SizedBox.shrink();
      }

      Duration previewPosition = 
          widget.myVideoStateController.previewPosition.value;
      Duration totalDuration = 
          widget.myVideoStateController.totalDuration.value;
      
      // 计算进度百分比
      double progress = totalDuration.inMilliseconds > 0 
          ? previewPosition.inMilliseconds / totalDuration.inMilliseconds 
          : 0.0;

      return Positioned(
        top: MediaQuery.of(context).padding.top + 20,
        left: 0,
        right: 0,
        child: Center(
          child: Container(
            width: 200, // 设置固定宽度
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 进度条
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[700],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 4,
                  ),
                ),
                const SizedBox(height: 8),
                // 时间对比
                Text(
                  '${CommonUtils.formatDuration(previewPosition)} / ${CommonUtils.formatDuration(totalDuration)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

/// 长按类型 [滑动也属于长按]
enum LongPressType {
  brightness,
  volume,
  normal,
}
