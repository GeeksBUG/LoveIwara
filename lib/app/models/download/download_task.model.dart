class DownloadTask {
  final String id;
  final String url;
  final String savePath;
  final String fileName;
  int totalBytes;
  int downloadedBytes;
  DownloadStatus status;
  bool supportsRange;
  String? error;
  int speed = 0; // 当前下载速度(bytes/s)
  DateTime? lastSpeedUpdateTime; // 上次速度更新时间
  int lastDownloadedBytes = 0; // 上次下载的字节数
  
  DownloadTask({
    required this.id,
    required this.url,
    required this.savePath,
    required this.fileName,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.status = DownloadStatus.pending,
    this.supportsRange = false,
    this.error,
  });

  // 从数据库行转换
  factory DownloadTask.fromRow(Map<String, dynamic> row) {
    return DownloadTask(
      id: row['id'],
      url: row['url'],
      savePath: row['save_path'],
      fileName: row['file_name'],
      totalBytes: row['total_bytes'] as int,
      downloadedBytes: row['downloaded_bytes'] as int,
      status: DownloadStatus.values.byName(row['status']),
      supportsRange: row['supports_range'] == 1,
      error: row['error'],
    );
  }

  // 转换为数据库行
  Map<String, dynamic> toRow() {
    return {
      'id': id,
      'url': url,
      'save_path': savePath,
      'file_name': fileName,
      'total_bytes': totalBytes,
      'downloaded_bytes': downloadedBytes,
      'status': status.name,
      'supports_range': supportsRange ? 1 : 0,
      'error': error,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  // 更新下载速度
  void updateSpeed() {
    final now = DateTime.now();
    if (lastSpeedUpdateTime != null) {
      final duration = now.difference(lastSpeedUpdateTime!).inSeconds;
      if (duration > 0) {
        final bytesDownloaded = downloadedBytes - lastDownloadedBytes;
        speed = (bytesDownloaded / duration).round();
      }
    }
    lastSpeedUpdateTime = now;
    lastDownloadedBytes = downloadedBytes;
  }
}

enum DownloadStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
}

class FileSystemException implements Exception {
  final String message;
  final FileErrorType type;

  FileSystemException({
    required this.message,
    required this.type,
  });
}

enum FileErrorType {
  accessDenied,     // 访问被拒绝
  notFound,         // 文件不存在
  alreadyExists,    // 文件已存在
  insufficientSpace,// 空间不足
  ioError,          // IO错误
}

class NetworkException implements Exception {
  final String message;
  final int? statusCode;
  final NetworkErrorType type;

  NetworkException({
    required this.message,
    this.statusCode,
    required this.type,
  });
}

enum NetworkErrorType {
  noNetwork,        // 无网络连接
  timeout,          // 连接超时
  serverError,      // 服务器错误
  invalidUrl,       // 无效URL
  canceledByUser,   // 用户取消
  storageNotEnough, // 存储空间不足
}