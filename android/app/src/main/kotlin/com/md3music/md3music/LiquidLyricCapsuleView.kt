package com.md3music.md3music

import android.content.Context
import android.graphics.*
import android.os.SystemClock
import android.text.TextUtils
import android.view.View
import kotlin.math.min
import kotlin.math.max

/** One frame clock for the playing cover and overflowing lyric; idle when paused. */
class LiquidLyricCapsuleView(context: Context) : View(context) {
    private val d = resources.displayMetrics.density
    private val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.SUBPIXEL_TEXT_FLAG or Paint.FILTER_BITMAP_FLAG)
    private val titlePaint = android.text.TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0xffcbbfdd.toInt(); textSize = 11.5f * d
        typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
    }
    private val lyricPaint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.SUBPIXEL_TEXT_FLAG).apply {
        color = 0xfff6f1ff.toInt(); textSize = 14f * d
        typeface = Typeface.create("sans-serif", Typeface.NORMAL)
    }
    private val rect = RectF()
    private val clip = Path()
    private var title = "md3Free"
    private var line = "已暂停"
    private var cover: Bitmap? = null
    private var playing = false
    private var screenOn = true
    private var elapsed = 0L
    private var tick = SystemClock.uptimeMillis()
    private var rotationElapsed = 0L
    private var rotationTick = SystemClock.uptimeMillis()
    private var opacity = 50
    private var measuredLine = 0f
    private var fill: Shader? = null
    private var edge: Shader? = null
    private var glint: Shader? = null

    fun setSongTitle(value: String) {
        if (value == title) return
        title = value.ifEmpty { "md3Free" }; line = ""; measuredLine = 0f
        cover?.recycle(); cover = null
        rotationElapsed = 0; rotationTick = SystemClock.uptimeMillis()
        elapsed = 0; tick = SystemClock.uptimeMillis(); invalidate()
    }
    fun setArtwork(bytes: ByteArray) {
        val previous = cover
        cover = if (bytes.isEmpty()) null else BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        previous?.recycle(); invalidate()
    }
    fun setLine(value: String) {
        if (value == line) return
        line = value; measuredLine = lyricPaint.measureText(value)
        elapsed = 0; tick = SystemClock.uptimeMillis(); invalidate()
    }
    private fun elapsedNow() = elapsed + if (playing && screenOn) SystemClock.uptimeMillis() - tick else 0
    private fun rotationNow() = rotationElapsed + if (playing && screenOn) SystemClock.uptimeMillis() - rotationTick else 0
    fun setPlaying(value: Boolean) {
        if (playing == value) return
        elapsed = elapsedNow(); rotationElapsed = rotationNow()
        tick = SystemClock.uptimeMillis(); rotationTick = tick
        playing = value; invalidate()
    }
    fun setScreenOn(value: Boolean) {
        elapsed = elapsedNow(); rotationElapsed = rotationNow()
        tick = SystemClock.uptimeMillis(); rotationTick = tick; screenOn = value
        if (value) invalidate()
    }
    fun setStyle(size: Float, alpha: Int) {
        lyricPaint.textSize = (if (size > 24) size * .4f else size).coerceIn(12f, 18f) * d
        measuredLine = lyricPaint.measureText(line); opacity = alpha.coerceIn(0, 100)
        updateShaders(width.toFloat(), height.toFloat()); invalidate()
    }
    private fun updateShaders(w: Float, h: Float) {
        if (w <= 0 || h <= 0) return
        val alpha = (100 + opacity * 1.35f).toInt()
        fill = LinearGradient(0f, 0f, w, h, intArrayOf(Color.argb(alpha, 63, 45, 82), Color.argb(alpha, 27, 23, 42)), null, Shader.TileMode.CLAMP)
        edge = LinearGradient(0f, 0f, w, h, intArrayOf(0xadfff9ff.toInt(), 0x18e9dcff, 0x6bcae8f4), floatArrayOf(0f, .55f, 1f), Shader.TileMode.CLAMP)
        glint = RadialGradient(w * .25f, 0f, 100f * d, intArrayOf(0x45f6f1ff, 0x00f6f1ff), null, Shader.TileMode.CLAMP)
    }
    override fun onSizeChanged(w: Int, h: Int, oldw: Int, oldh: Int) { updateShaders(w.toFloat(), h.toFloat()) }
    override fun onMeasure(w: Int, h: Int) { setMeasuredDimension(resolveSize((280*d).toInt(), w), resolveSize((64*d).toInt(), h)) }
    override fun onDetachedFromWindow() { super.onDetachedFromWindow(); cover?.recycle(); cover = null }
    override fun onDraw(canvas: Canvas) {
        val w = width.toFloat(); val h = height.toFloat()
        rect.set(.7f*d,.7f*d,w-.7f*d,h-.7f*d)
        paint.style = Paint.Style.FILL; paint.shader = fill
        canvas.drawRoundRect(rect, h/2, h/2, paint)
        paint.shader = glint; canvas.drawRoundRect(rect, h/2, h/2, paint)
        paint.style = Paint.Style.STROKE; paint.strokeWidth = 1.1f*d; paint.shader = edge
        canvas.drawRoundRect(rect, h/2, h/2, paint)
        paint.shader = null; paint.style = Paint.Style.FILL
        val art = RectF(9*d,9*d,55*d,55*d)
        clip.reset(); clip.addOval(art,Path.Direction.CW)
        canvas.save(); canvas.clipPath(clip)
        val image = cover
        if (image != null && !image.isRecycled) {
            canvas.rotate((rotationNow() % 22000L) * 360f / 22000f, art.centerX(), art.centerY())
            val side = min(image.width,image.height)
            canvas.drawBitmap(image,Rect((image.width-side)/2,(image.height-side)/2,(image.width+side)/2,(image.height+side)/2),art,paint)
        } else {
            paint.color = 0xff3c3050.toInt(); canvas.drawOval(art,paint)
            paint.color = 0xff96e2d0.toInt(); paint.textSize = 25*d
            canvas.drawText("♪",22*d,42*d,paint)
        }
        canvas.restore()
        paint.color=0x40ffffff; paint.style=Paint.Style.STROKE;paint.strokeWidth=.8f*d
        canvas.drawOval(art,paint);paint.style=Paint.Style.FILL
        val x=66*d; val available=max(1f,w-x-14*d)
        canvas.drawText(TextUtils.ellipsize(title,titlePaint,available,TextUtils.TruncateAt.END).toString(),x,25*d,titlePaint)
        val shown=line.ifEmpty { if(playing) "音乐播放中" else "已暂停" }
        val textWidth=if(line.isEmpty()) lyricPaint.measureText(shown) else measuredLine
        val distance=max(0f,textWidth-available)
        var offset=0f
        if(distance>1) {
            val travel=distance/(24*d)*1000
            val t=(elapsedNow() % (travel*2+2000).toLong()).toFloat()
            offset=when { t<1000 -> 0f; t<1000+travel -> (t-1000)/travel*distance; t<2000+travel -> distance; else -> (1-(t-2000-travel)/travel)*distance }
        }
        canvas.save();canvas.clipRect(x,30*d,x+available,57*d)
        canvas.drawText(shown,x-offset,47*d,lyricPaint);canvas.restore()
        if((cover != null || distance>1) && playing && screenOn && isShown) postInvalidateOnAnimation()
    }
}
