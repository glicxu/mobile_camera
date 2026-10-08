package com.dalicamera.dali_camera_platform

import android.content.Context
import android.graphics.*
import android.view.View
import kotlin.math.min

internal class DepthPreviewView(context: Context) : View(context) {
    var level = 0
    var subject: RectF? = null
    var aspect = .75
    private var image: Bitmap? = null
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG)
    fun replace(bitmap: Bitmap?) { image?.recycle(); image = bitmap; invalidate() }
    override fun onDraw(canvas: Canvas) {
        val bitmap = image ?: return; val rect = subject ?: return
        if (level == 0) return
        val w = min(width.toDouble(), height * aspect).toFloat(); val h = (w / aspect).toFloat()
        val content = RectF((width - w) / 2, (height - h) / 2, (width + w) / 2, (height + h) / 2)
        val subjectPixels = RectF(content.left + rect.left * w, content.top + rect.top * h, content.left + rect.right * w, content.top + rect.bottom * h)
        val path = Path().apply { fillType = Path.FillType.EVEN_ODD; addRect(content, Path.Direction.CW); addRoundRect(subjectPixels, min(subjectPixels.width(), subjectPixels.height()) * .28f, min(subjectPixels.width(), subjectPixels.height()) * .28f, Path.Direction.CW) }
        canvas.save(); canvas.clipPath(path)
        paint.alpha = ((.30 + level * .09) * 255).toInt()
        canvas.drawBitmap(bitmap, null, RectF(0f, 0f, width.toFloat(), height.toFloat()), paint)
        canvas.restore()
    }
}
