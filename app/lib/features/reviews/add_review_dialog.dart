import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../data/repositories/reviews_repository.dart';

class AddReviewDialog extends ConsumerStatefulWidget {
  final int bookingId;
  final String chargerTitle;

  const AddReviewDialog({
    super.key,
    required this.bookingId,
    required this.chargerTitle,
  });

  @override
  ConsumerState<AddReviewDialog> createState() => _AddReviewDialogState();
}

class _AddReviewDialogState extends ConsumerState<AddReviewDialog> {
  int _rating = 5;
  final _commentCtrl = TextEditingController();
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await ref.read(reviewsRepositoryProvider).submitReview(
            bookingId: widget.bookingId,
            rating: _rating,
            comment: _commentCtrl.text.trim().isEmpty ? null : _commentCtrl.text.trim(),
          );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = 'Could not submit review: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.surface,
      title: Text('Rate Charging Experience\n${widget.chargerTitle}', style: const TextStyle(fontSize: 16)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starIndex = index + 1;
                return IconButton(
                  icon: Icon(
                    starIndex <= _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 32,
                  ),
                  onPressed: () => setState(() => _rating = starIndex),
                );
              }),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(_error!, style: const TextStyle(color: AppTheme.error, fontSize: 12)),
              ),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Share your charging speed, host support, parking ease...',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Submit Review'),
        ),
      ],
    );
  }
}

