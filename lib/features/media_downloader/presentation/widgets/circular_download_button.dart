import 'package:flutter/material.dart';

class CircularDownloadButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final double progress;
  final bool isDownloading;
  final bool isCompleted;
  final double size;

  const CircularDownloadButton({
    super.key,
    this.onPressed,
    this.progress = 0.0,
    this.isDownloading = false,
    this.isCompleted = false,
    this.size = 64.0,
  });

  @override
  State<CircularDownloadButton> createState() => _CircularDownloadButtonState();
}

class _CircularDownloadButtonState extends State<CircularDownloadButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    if (widget.isDownloading) {
      _animationController.repeat();
    }
  }

  @override
  void didUpdateWidget(CircularDownloadButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDownloading && !oldWidget.isDownloading) {
      _animationController.repeat();
    } else if (!widget.isDownloading && oldWidget.isDownloading) {
      _animationController.stop();
      _animationController.reset();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: widget.onPressed,
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.isCompleted
              ? Colors.green
              : widget.isDownloading
                  ? theme.primaryColor
                  : theme.colorScheme.secondary,
          boxShadow: [
            BoxShadow(
              color: (widget.isCompleted
                      ? Colors.green
                      : widget.isDownloading
                          ? theme.primaryColor
                          : theme.colorScheme.secondary)
                  .withOpacity(0.3),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Progress circle
            if (widget.isDownloading && widget.progress > 0)
              SizedBox(
                width: widget.size,
                height: widget.size,
                child: CircularProgressIndicator(
                  value: widget.progress,
                  strokeWidth: 3,
                  backgroundColor: Colors.white.withOpacity(0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),

            // Icon
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: widget.isCompleted
                  ? const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 32,
                      key: ValueKey('check'),
                    )
                  : widget.isDownloading
                      ? RotationTransition(
                          turns: _animationController,
                          child: const Icon(
                            Icons.download,
                            color: Colors.white,
                            size: 28,
                            key: ValueKey('downloading'),
                          ),
                        )
                      : const Icon(
                          Icons.download_rounded,
                          color: Colors.white,
                          size: 32,
                          key: ValueKey('download'),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

