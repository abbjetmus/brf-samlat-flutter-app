import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// A circular avatar/photo thumbnail with an overlaid action button. When a
/// [photoUrl] is set the button removes the image; otherwise it picks a new one.
class ImageThumbnail extends StatelessWidget {
  final double size;
  final String? photoUrl;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;

  const ImageThumbnail({
    super.key,
    required this.size,
    this.photoUrl,
    required this.onPickImage,
    required this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.grey.shade300, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: photoUrl != null
              ? ClipOval(
                  child: Image.network(
                    photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.person,
                      size: size / 2.5,
                      color: Colors.grey.shade500,
                    ),
                  ),
                )
              : Icon(
                  Icons.person,
                  size: size / 2.5,
                  color: Colors.grey.shade500,
                ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            decoration: BoxDecoration(
              color: photoUrl != null ? Colors.red : AppTheme.primaryColor,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: photoUrl != null ? onRemoveImage : onPickImage,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    photoUrl != null ? Icons.delete : Icons.add,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
