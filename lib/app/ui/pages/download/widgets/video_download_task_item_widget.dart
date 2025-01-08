import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:i_iwara/app/models/download/download_task.model.dart';
import 'package:i_iwara/app/models/download/download_task_ext_data.model.dart';
import 'package:i_iwara/app/services/app_service.dart';
import 'package:i_iwara/app/services/download_service.dart';
import 'package:i_iwara/app/ui/widgets/MDToastWidget.dart';
import 'package:i_iwara/utils/logger_utils.dart';
import 'package:oktoast/oktoast.dart';
import 'package:open_file/open_file.dart';
import 'package:super_clipboard/super_clipboard.dart';

class VideoDownloadTaskItem extends StatelessWidget {
  final DownloadTask task;

  const VideoDownloadTaskItem({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final videoData = VideoDownloadExtData.fromJson(task.extData!.data);
    final width = MediaQuery.of(context).size.width;
    final isSmallScreen = width < 600;
    
    // 从任务ID中提取清晰度信息
    final quality = task.id.split('_').last;

    return GestureDetector(
      onSecondaryTapUp: (details) =>
          _showContextMenu(context, details.globalPosition),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: InkWell(
          onTap: () => _onTap(context),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 视频缩略图
                    if (videoData.thumbnail != null)
                      Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: videoData.thumbnail!,
                              width: isSmallScreen ? 120 : 160,
                              height: isSmallScreen ? 68 : 90,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: Colors.grey[300],
                                child: const Center(
                                    child: CircularProgressIndicator()),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.error),
                              ),
                            ),
                          ),
                          // 清晰度标签
                          Positioned(
                            left: 4,
                            top: 4,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                quality,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 视频标题
                          Text(
                            videoData.title ?? task.fileName,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          // 作者信息
                          if (videoData.authorName != null)
                            Row(
                              children: [
                                if (videoData.authorAvatar != null &&
                                    !isSmallScreen)
                                  MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: () =>
                                          _navigateToAuthorProfile(videoData),
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        margin: const EdgeInsets.only(right: 8),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          child: CachedNetworkImage(
                                            imageUrl: videoData.authorAvatar!,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) =>
                                                Container(
                                              color: Colors.grey[300],
                                            ),
                                            errorWidget:
                                                (context, url, error) =>
                                                    Container(
                                              color: Colors.grey[300],
                                              child: const Icon(Icons.person,
                                                  size: 16),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                Expanded(
                                  child: MouseRegion(
                                    cursor: SystemMouseCursors.click,
                                    child: GestureDetector(
                                      onTap: () =>
                                          _navigateToAuthorProfile(videoData),
                                      child: Text(
                                        videoData.authorName!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          if (!isSmallScreen) const SizedBox(height: 4),
                          // 视频时长
                          if (videoData.duration != null && !isSmallScreen)
                            Text(
                              _formatDuration(videoData.duration!),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                            ),
                        ],
                      ),
                    ),
                    // 主要操作按钮
                    _buildMainActionButton(context),
                  ],
                ),
                const SizedBox(height: 8),
                // 进度条和状态
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProgressIndicator(),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_getStatusText()),
                              if (task.error != null)
                                Text(
                                  task.error!,
                                  style: const TextStyle(color: Colors.red),
                                ),
                            ],
                          ),
                        ),
                        // 视频详情跳转按钮
                        if (videoData.id != null)
                          IconButton(
                            icon: const Icon(Icons.video_library),
                            tooltip: '查看视频详情',
                            onPressed: () =>
                                NaviService.navigateToVideoDetailPage(
                                    videoData.id!),
                          ),
                        // 更多操作按钮
                        IconButton(
                          icon: const Icon(Icons.more_horiz),
                          onPressed: () => _showMoreOptionsDialog(context),
                          tooltip: '更多操作',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainActionButton(BuildContext context) {
    switch (task.status) {
      case DownloadStatus.downloading:
        return IconButton(
          icon: const Icon(Icons.pause),
          tooltip: '暂停',
          onPressed: () => DownloadService.to.pauseTask(task.id),
        );
      case DownloadStatus.paused:
        return IconButton(
          icon: const Icon(Icons.play_arrow),
          tooltip: '继续',
          onPressed: () => DownloadService.to.resumeTask(task.id),
        );
      case DownloadStatus.failed:
        return IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: '重试',
          onPressed: () => DownloadService.to.retryTask(task.id),
        );
      case DownloadStatus.completed:
        return IconButton(
          icon: const Icon(Icons.play_circle_outline),
          tooltip: '打开',
          onPressed: () => _openFile(context),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  void _showMoreOptionsDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 复制下载链接
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('复制下载链接'),
              onTap: () {
                Navigator.pop(context);
                _copyDownloadUrl(context);
              },
            ),
            if (task.status == DownloadStatus.completed) ...[
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: const Text('打开文件'),
                onTap: () {
                  Navigator.pop(context);
                  _openFile(context);
                },
              ),
              if (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
                ListTile(
                  leading: const Icon(Icons.folder_open),
                  title: const Text('在文件夹中显示'),
                  onTap: () {
                    Navigator.pop(context);
                    _showInFolder(context);
                  },
                ),
            ],
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除任务', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteConfirmDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position) {
    final RenderBox overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        position & const Size(40, 40),
        Offset.zero & overlay.size,
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.link, size: 20),
              const SizedBox(width: 12),
              const Text('复制下载链接'),
            ],
          ),
          onTap: () => _copyDownloadUrl(context),
        ),
        if (task.status == DownloadStatus.completed) ...[
          if (Platform.isWindows || Platform.isMacOS || Platform.isLinux)
            PopupMenuItem(
              child: Row(
                children: [
                  const Icon(Icons.folder_open, size: 20),
                  const SizedBox(width: 12),
                  const Text('在文件夹中显示'),
                ],
              ),
              onTap: () => _showInFolder(context),
            ),
          PopupMenuItem(
            child: Row(
              children: [
                const Icon(Icons.open_in_new, size: 20),
                const SizedBox(width: 12),
                const Text('打开文件'),
              ],
            ),
            onTap: () => _openFile(context),
          ),
        ],
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.delete, size: 20, color: Colors.red),
              const SizedBox(width: 12),
              const Text('删除任务', style: TextStyle(color: Colors.red)),
            ],
          ),
          onTap: () => _showDeleteConfirmDialog(context),
        ),
      ],
    );
  }

  void _navigateToAuthorProfile(VideoDownloadExtData videoData) {
    if (videoData.authorUsername != null) {
      NaviService.navigateToAuthorProfilePage(videoData.authorUsername!);
    }
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes;
    final remainingSeconds = duration.inSeconds - minutes * 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildProgressIndicator() {
    if (task.status == DownloadStatus.downloading) {
      if (task.totalBytes > 0) {
        return LinearProgressIndicator(
          value: task.downloadedBytes / task.totalBytes,
          backgroundColor: Colors.grey[200],
          valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
        );
      } else {
        return const LinearProgressIndicator(
          backgroundColor: Colors.grey,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        );
      }
    } else {
      return LinearProgressIndicator(
        value: task.status == DownloadStatus.completed ? 1.0 : 0.0,
        backgroundColor: Colors.grey[200],
        valueColor: AlwaysStoppedAnimation<Color>(
          _getProgressColor(task.status),
        ),
      );
    }
  }

  Color _getProgressColor(DownloadStatus status) {
    switch (status) {
      case DownloadStatus.completed:
        return Colors.green;
      case DownloadStatus.failed:
        return Colors.red;
      case DownloadStatus.paused:
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }

  String _getStatusText() {
    switch (task.status) {
      case DownloadStatus.pending:
        return '等待下载...';
      case DownloadStatus.downloading:
        if (task.totalBytes > 0) {
          final progress =
              (task.downloadedBytes / task.totalBytes * 100).toStringAsFixed(1);
          final downloaded = _formatFileSize(task.downloadedBytes);
          final total = _formatFileSize(task.totalBytes);
          final speed = (task.speed / 1024 / 1024).toStringAsFixed(2);
          return '下载中 $downloaded/$total ($progress%) • ${speed}MB/s';
        } else {
          final downloaded = _formatFileSize(task.downloadedBytes);
          final speed = (task.speed / 1024 / 1024).toStringAsFixed(2);
          return '下载中 $downloaded • ${speed}MB/s';
        }
      case DownloadStatus.paused:
        if (task.totalBytes > 0) {
          final progress =
              (task.downloadedBytes / task.totalBytes * 100).toStringAsFixed(1);
          final downloaded = _formatFileSize(task.downloadedBytes);
          final total = _formatFileSize(task.totalBytes);
          return '已暂停 • $downloaded/$total ($progress%)';
        } else {
          final downloaded = _formatFileSize(task.downloadedBytes);
          return '已暂停 • 已下载 $downloaded';
        }
      case DownloadStatus.completed:
        final size = _formatFileSize(task.downloadedBytes);
        return '下载完成 • $size';
      case DownloadStatus.failed:
        return '下载失败';
    }
  }

  String _formatFileSize(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = bytes.toDouble();
    int unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    String sizeStr =
        size >= 10 ? size.round().toString() : size.toStringAsFixed(1);
    return '$sizeStr ${units[unitIndex]}';
  }

  Future<void> _copyDownloadUrl(BuildContext context) async {
    try {
      final item = DataWriterItem();
      item.add(Formats.plainText(task.url));
      await SystemClipboard.instance?.write([item]);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已复制下载链接')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('复制失败')),
        );
      }
    }
  }

  Future<void> _showInFolder(BuildContext context) async {
    try {
      final filePath = _normalizePath(task.savePath);
      LogUtils.d('显示文件夹: $filePath', 'DownloadTaskItem');

      final file = File(filePath);
      if (!await file.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文件不存在')),
          );
        }
        return;
      }

      if (Platform.isWindows) {
        final windowsPath = filePath.replaceAll('/', '\\');
        await Process.run('explorer.exe', ['/select,', windowsPath]);
      } else if (Platform.isMacOS) {
        await Process.run('open', ['-R', filePath]);
      } else if (Platform.isLinux) {
        final directory = File(filePath).parent.path;
        await Process.run('xdg-open', [directory]);
      }
    } catch (e) {
      LogUtils.e('打开文件夹失败', tag: 'DownloadTaskItem', error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('打开文件夹失败')),
        );
      }
    }
  }

  Future<void> _openFile(BuildContext context) async {
    try {
      final filePath = _normalizePath(task.savePath);
      LogUtils.d('打开文件: $filePath', 'DownloadTaskItem');

      final file = File(filePath);
      if (!await file.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文件不存在')),
          );
        }
        return;
      }

      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        LogUtils.e('打开文件失败: ${result.message}', tag: 'DownloadTaskItem');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('打开文件失败: ${result.message}')),
          );
        }
      }
    } catch (e) {
      LogUtils.e('打开文件失败', tag: 'DownloadTaskItem', error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('打开文件失败')),
        );
      }
    }
  }

  String _normalizePath(String path) {
    if (Platform.isWindows) {
      return path.replaceAll('/', '\\');
    } else {
      return path.replaceAll('\\', '/');
    }
  }

  void _onTap(BuildContext context) {
    if (task.status == DownloadStatus.completed) {
      _openFile(context);
    } else {
      // 如果是视频类型且有视频ID，可以跳转到视频详情页
      final videoData = VideoDownloadExtData.fromJson(task.extData!.data);
      if (videoData.id != null) {
        NaviService.navigateToVideoDetailPage(videoData.id!);
      }
    }
  }

  void _showDeleteConfirmDialog(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('删除下载任务'),
        content: const Text('确定要删除该下载任务吗?已下载的文件也会被删除。'),
        actions: [
          TextButton(
            onPressed: () => AppService.tryPop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              AppService.tryPop();
              DownloadService.to.deleteTask(task.id);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }
}
