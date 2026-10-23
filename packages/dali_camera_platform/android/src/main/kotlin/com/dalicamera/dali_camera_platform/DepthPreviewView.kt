package com.dalicamera.dali_camera_platform

import android.content.Context
import android.graphics.*
import android.view.View
import kotlin.math.*

internal class DepthPreviewView(context: Context) : View(context) {
    var level = 0
    var subject: RectF? = null
    var focus = PointF(.5f, .5f)
    var aspect = .75
    private var images: List<Bitmap> = emptyList()
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    fun replace(bitmaps: List<Bitmap>?) {
        images.forEach { it.recycle() }
        images = bitmaps.orEmpty()
        invalidate()
    }
    override fun onDraw(canvas: Canvas) {
        if (images.isEmpty()) return
        val rect = subject ?: return
        if (level == 0) return
        val w = min(width.toDouble(), height * aspect).toFloat(); val h = (w / aspect).toFloat()
        val content = RectF((width - w) / 2, (height - h) / 2, (width + w) / 2, (height + h) / 2)
        val subjectPixels = RectF(content.left + rect.left * w, content.top + rect.top * h, content.left + rect.right * w, content.top + rect.bottom * h)
        val path = Path().apply { fillType = Path.FillType.EVEN_ODD; addRect(content, Path.Direction.CW); addRoundRect(subjectPixels, min(subjectPixels.width(), subjectPixels.height()) * .28f, min(subjectPixels.width(), subjectPixels.height()) * .28f, Path.Direction.CW) }
        canvas.save(); canvas.clipPath(path)
        val centerX = content.left + focus.x.coerceIn(0f, 1f) * content.width()
        val centerY = content.top + focus.y.coerceIn(0f, 1f) * content.height()
        val farthest = maxOf(
            hypot(centerX - content.left, centerY - content.top), hypot(content.right - centerX, centerY - content.top),
            hypot(centerX - content.left, content.bottom - centerY), hypot(content.right - centerX, content.bottom - centerY)
        ).coerceAtLeast(1f)
        val bands = arrayOf(.02f to .28f, .24f to .52f, .48f to .76f, .72f to 1f)
        images.take(bands.size).forEachIndexed { index, bitmap ->
            val checkpoint = canvas.saveLayer(content, null)
            paint.alpha = 255; paint.shader = null; paint.xfermode = null
            canvas.drawBitmap(bitmap, null, RectF(0f, 0f, width.toFloat(), height.toFloat()), paint)
            paint.shader = RadialGradient(
                centerX, centerY, farthest,
                intArrayOf(Color.TRANSPARENT, Color.WHITE),
                floatArrayOf(bands[index].first, bands[index].second),
                Shader.TileMode.CLAMP
            )
            paint.xfermode = PorterDuffXfermode(PorterDuff.Mode.DST_IN)
            canvas.drawRect(content, paint)
            paint.shader = null; paint.xfermode = null
            canvas.restoreToCount(checkpoint)
        }
        canvas.restore()
    }
}
