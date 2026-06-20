import 'package:flutter/material.dart';

const String _pbBaseUrl = 'https://brf-samlat-pb.cloud.mustini.com';

String getImageUrl(String collectionId, String recordId, String filename) {
  return '$_pbBaseUrl/api/files/$collectionId/$recordId/$filename';
}

String getImageUrlThumb(
  String collectionId,
  String recordId,
  String filename, {
  String size = '100x100',
}) {
  return '$_pbBaseUrl/api/files/$collectionId/$recordId/$filename?thumb=$size';
}

class FileInfo {
  final String name;
  final String extension;
  final IconData icon;
  final bool isImage;

  const FileInfo({
    required this.name,
    required this.extension,
    required this.icon,
    this.isImage = false,
  });
}

FileInfo parseFilename(String filename) {
  // PocketBase appends a random suffix before the extension
  // e.g., "document_abc123.pdf" → "document.pdf"
  final parts = filename.split('.');
  final ext = parts.length > 1 ? parts.last.toLowerCase() : '';

  // Remove PocketBase random suffix from name
  String name = parts.length > 1 ? parts.sublist(0, parts.length - 1).join('.') : filename;
  final underscoreParts = name.split('_');
  if (underscoreParts.length > 1) {
    final lastPart = underscoreParts.last;
    if (lastPart.length >= 10 && RegExp(r'^[a-zA-Z0-9]+$').hasMatch(lastPart)) {
      name = underscoreParts.sublist(0, underscoreParts.length - 1).join('_');
    }
  }

  final imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'svg', 'bmp'];
  final isImage = imageExtensions.contains(ext);

  IconData icon;
  switch (ext) {
    case 'pdf':
      icon = Icons.picture_as_pdf;
      break;
    case 'doc':
    case 'docx':
      icon = Icons.description;
      break;
    case 'xls':
    case 'xlsx':
      icon = Icons.table_chart;
      break;
    case 'ppt':
    case 'pptx':
      icon = Icons.slideshow;
      break;
    case 'zip':
    case 'rar':
    case '7z':
      icon = Icons.archive;
      break;
    case 'mp3':
    case 'wav':
    case 'ogg':
      icon = Icons.audio_file;
      break;
    case 'mp4':
    case 'avi':
    case 'mov':
      icon = Icons.video_file;
      break;
    default:
      icon = isImage ? Icons.image : Icons.insert_drive_file;
  }

  return FileInfo(
    name: name.isNotEmpty ? name : filename,
    extension: ext,
    icon: icon,
    isImage: isImage,
  );
}

String byteToMegabyte(int bytes) {
  return (bytes / (1024 * 1024)).toStringAsFixed(2);
}

/// Max upload size per file, in bytes (8 MiB). Mirrors the PocketBase
/// `folders_and_files.files` field `maxSize`; keep the two in sync.
const int kMaxUploadBytes = 8 * 1024 * 1024;
