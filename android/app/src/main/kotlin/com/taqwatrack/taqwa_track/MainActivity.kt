package com.taqwatrack.taqwa_track

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel

/**
 * Liefert die aktuelle Blickrichtung des Geräts (0–360°, 0 = Norden)
 * über den EventChannel "taqwa_track/compass".
 */
class MainActivity : FlutterActivity(), EventChannel.StreamHandler, SensorEventListener {

    private val channelName = "taqwa_track/compass"
    private var sensorManager: SensorManager? = null
    private var rotationSensor: Sensor? = null
    private var fallbackSensors: List<Sensor> = emptyList()
    private var events: EventChannel.EventSink? = null

    private val rotationMatrix = FloatArray(9)
    private val orientation = FloatArray(3)
    private val gravity = FloatArray(3)
    private val geomagnetic = FloatArray(3)
    private var hasGravity = false
    private var hasGeomagnetic = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val manager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        sensorManager = manager
        rotationSensor = manager?.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
            ?: manager?.getDefaultSensor(Sensor.TYPE_GAME_ROTATION_VECTOR)
        fallbackSensors = listOfNotNull(
            manager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER),
            manager?.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
        )
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
        events = sink
        val manager = sensorManager ?: return
        val rotation = rotationSensor
        if (rotation != null) {
            manager.registerListener(this, rotation, SensorManager.SENSOR_DELAY_UI)
        } else {
            for (sensor in fallbackSensors) {
                manager.registerListener(this, sensor, SensorManager.SENSOR_DELAY_UI)
            }
        }
    }

    override fun onCancel(arguments: Any?) {
        sensorManager?.unregisterListener(this)
        events = null
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null) return
        if (event.sensor.type == Sensor.TYPE_ACCELEROMETER) {
            System.arraycopy(event.values, 0, gravity, 0, gravity.size)
            hasGravity = true
        } else if (event.sensor.type == Sensor.TYPE_MAGNETIC_FIELD) {
            System.arraycopy(event.values, 0, geomagnetic, 0, geomagnetic.size)
            hasGeomagnetic = true
        } else {
            SensorManager.getRotationMatrixFromVector(rotationMatrix, event.values)
        }
        if (rotationSensor == null) {
            if (!hasGravity || !hasGeomagnetic) return
            val success = SensorManager.getRotationMatrix(
                rotationMatrix, null, gravity, geomagnetic
            )
            if (!success) return
        }
        SensorManager.getOrientation(rotationMatrix, orientation)
        var degrees = Math.toDegrees(orientation[0].toDouble())
        degrees = (degrees + 360.0) % 360.0
        events?.success(degrees)
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    override fun onPause() {
        sensorManager?.unregisterListener(this)
        super.onPause()
    }

    override fun onResume() {
        super.onResume()
        if (events != null) {
            onListen(null, events)
        }
    }
}
