package com.example.she_safe

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.CellInfo
import android.telephony.CellInfoCdma
import android.telephony.CellInfoGsm
import android.telephony.CellInfoLte
import android.telephony.CellInfoNr
import android.telephony.CellInfoWcdma
import android.telephony.CellSignalStrengthNr
import android.telephony.TelephonyManager
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.shesafe/cell_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getCellInfo" -> {
                    val cellInfoList = getCellTowerInfo()
                    if (cellInfoList != null) {
                        result.success(cellInfoList)
                    } else {
                        result.error("UNAVAILABLE", "Cell info not available", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getCellTowerInfo(): List<Map<String, Any?>>? {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) 
            != PackageManager.PERMISSION_GRANTED) {
            return null
        }

        val telephonyManager = getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        val cellInfoList = telephonyManager.allCellInfo ?: return null

        return cellInfoList.mapNotNull { cellInfo ->
            parseCellInfo(cellInfo)
        }
    }

    private fun parseCellInfo(cellInfo: CellInfo): Map<String, Any?>? {
        return when (cellInfo) {
            is CellInfoLte -> {
                val identity = cellInfo.cellIdentity
                val signal = cellInfo.cellSignalStrength
                mapOf(
                    "cellId" to identity.ci,
                    "lac" to identity.tac,
                    "mcc" to (if (Build.VERSION.SDK_INT >= 28) identity.mccString?.toIntOrNull() ?: 0 else 0),
                    "mnc" to (if (Build.VERSION.SDK_INT >= 28) identity.mncString?.toIntOrNull() ?: 0 else 0),
                    "signalStrength" to signal.dbm,
                    "networkType" to "LTE",
                    "isRegistered" to cellInfo.isRegistered,
                    "latitude" to null,
                    "longitude" to null
                )
            }
            is CellInfoGsm -> {
                val identity = cellInfo.cellIdentity
                val signal = cellInfo.cellSignalStrength
                mapOf(
                    "cellId" to identity.cid,
                    "lac" to identity.lac,
                    "mcc" to (if (Build.VERSION.SDK_INT >= 28) identity.mccString?.toIntOrNull() ?: 0 else 0),
                    "mnc" to (if (Build.VERSION.SDK_INT >= 28) identity.mncString?.toIntOrNull() ?: 0 else 0),
                    "signalStrength" to signal.dbm,
                    "networkType" to "GSM",
                    "isRegistered" to cellInfo.isRegistered,
                    "latitude" to null,
                    "longitude" to null
                )
            }
            is CellInfoWcdma -> {
                val identity = cellInfo.cellIdentity
                val signal = cellInfo.cellSignalStrength
                mapOf(
                    "cellId" to identity.cid,
                    "lac" to identity.lac,
                    "mcc" to (if (Build.VERSION.SDK_INT >= 28) identity.mccString?.toIntOrNull() ?: 0 else 0),
                    "mnc" to (if (Build.VERSION.SDK_INT >= 28) identity.mncString?.toIntOrNull() ?: 0 else 0),
                    "signalStrength" to signal.dbm,
                    "networkType" to "WCDMA",
                    "isRegistered" to cellInfo.isRegistered,
                    "latitude" to null,
                    "longitude" to null
                )
            }
            is CellInfoCdma -> {
                val identity = cellInfo.cellIdentity
                val signal = cellInfo.cellSignalStrength
                mapOf(
                    "cellId" to identity.basestationId,
                    "lac" to identity.networkId,
                    "mcc" to 0,
                    "mnc" to identity.systemId,
                    "signalStrength" to signal.dbm,
                    "networkType" to "CDMA",
                    "isRegistered" to cellInfo.isRegistered,
                    "latitude" to null,
                    "longitude" to null
                )
            }
            else -> {
                // Handle NR (5G) on API 29+
                if (Build.VERSION.SDK_INT >= 29 && cellInfo is CellInfoNr) {
                    val identity = cellInfo.cellIdentity as? android.telephony.CellIdentityNr
                    val signal = cellInfo.cellSignalStrength as? CellSignalStrengthNr
                    if (identity != null && signal != null) {
                        mapOf(
                            "cellId" to (identity.nci.toInt()),
                            "lac" to identity.tac,
                            "mcc" to (identity.mccString?.toIntOrNull() ?: 0),
                            "mnc" to (identity.mncString?.toIntOrNull() ?: 0),
                            "signalStrength" to signal.dbm,
                            "networkType" to "NR",
                            "isRegistered" to cellInfo.isRegistered,
                            "latitude" to null,
                            "longitude" to null
                        )
                    } else null
                } else null
            }
        }
    }
}
