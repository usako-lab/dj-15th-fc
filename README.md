# ArduCopter で Lua Script を使用して mode ZIGZAG を動かす。

### 動作方法

* copter-zigzag.lua を scripts ディレクトリに配置する。
* sim_vehicle.py 起動する。
* mode GUIDED とする。
* arm throttle とする。
* 下記と screencast.webm を参照。

```
$ sim_vehicle.py -N -v ArduCopter -L Kawachi --console --map
SIM_VEHICLE: Start
...
STABILIZE> mode guided
GUIDED> arm throttle
```

### 作成するにあたって

* MAVProxy の console を使用して「どのようにすれば動くのか？」を試す。
* 上記から Lua Script を作成する。

### 実際に作成してみて

* console での手順と同じように、思うように、なかなか出来なかった。
* ZIGZAG の PointA, PointB を設定するにあたり、ZIGZAG 中に set_target_pos_NED() 等での移動は出来ないので悩んだ。
* 今回は時間の都合上、GUIDED で set_target_pos_NED() を使用して移動した位置を PointB とし、その後、RC1, RC2 を使用して数秒移動した位置を PointA とした。
* 現在の位置でなくても、PointA, PointB の設定が出来るような変更は試してみようと思う。

