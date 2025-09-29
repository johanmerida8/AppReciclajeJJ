import 'package:flutter/material.dart';

class AddPhotoButton extends StatelessWidget {
  final VoidCallback? onAddPhoto;
  final int currentCount;
  final int maxPhotos;
  final bool isLoading;

  const AddPhotoButton({
    super.key,
    this.onAddPhoto,
    required this.currentCount,
    this.maxPhotos = 5,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final canAddMore = currentCount < maxPhotos;
    final isAtLimit = currentCount >= maxPhotos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Add photo button
        Center(
          child: GestureDetector(
            onTap: canAddMore && !isLoading ? onAddPhoto : null,
            child: Container(
              padding: const EdgeInsets.all(16),
              width: 120,
              decoration: BoxDecoration(
                color: canAddMore && !isLoading 
                    ? const Color(0xFF2D8A8A).withOpacity(0.1)
                    : Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: canAddMore && !isLoading 
                      ? const Color(0xFF2D8A8A)
                      : Colors.grey,
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isLoading)
                    const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        color: Color(0xFF2D8A8A),
                        strokeWidth: 3,
                      ),
                    )
                  else
                    Icon(
                      Icons.add_a_photo,
                      color: canAddMore 
                          ? const Color(0xFF2D8A8A)
                          : Colors.grey.shade600,
                      size: 32,
                    ),
                  const SizedBox(height: 12),
                  Text(
                    isLoading 
                        ? 'Subiendo...' 
                        : isAtLimit 
                            ? 'Límite\nAlcanzado' 
                            : 'Agregar\nFoto',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: canAddMore && !isLoading
                          ? const Color(0xFF2D8A8A)
                          : Colors.grey.shade600,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        // Status text
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Fotos: $currentCount/$maxPhotos${isAtLimit ? ' • Límite alcanzado' : ' • Toca para agregar'}',
            style: TextStyle(
              fontSize: 11,
              color: isAtLimit ? Colors.orange : Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}