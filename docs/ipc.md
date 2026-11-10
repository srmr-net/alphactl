# Local IPC, version 1

Transport: HTTP/1.1 over `/run/alphactl/control.sock`. Socket filesystem
permissions authorize every operation. The daemon accepts no caller-supplied
filesystem paths. Hardware operations are serialized, including HDMI toggle's
read and write. Other programs writing sysfs directly are outside this lock.

| Method | Path | JSON body |
| --- | --- | --- |
| GET | `/v1/status` | none |
| POST | `/v1/led` | `{"zone":"all","color":"FF8000"}` |
| POST | `/v1/brightness` | `{"value":8}` |
| POST | `/v1/hdmi` | `{"source":"toggle"}` |

LED zones: `all`, `zone00`, `zone01`. Colours: six hexadecimal digits, optionally
prefixed with `#`. Brightness: integer `0..max_brightness`. HDMI sources: `gpu`,
`input`, `toggle`. Toggle fails if the current source is unknown.

Successful mutations return HTTP 200 and `{"ok":true}`. Status returns:

```json
{"zones":{"zone00":"red: 0, green: 0, blue: 0","zone01":"red: 0, green: 0, blue: 0"},"brightness":15,"max_brightness":15,"source":"gpu","cable":"unconnected"}
```

HDMI source/cable values can be `unknown`. Requests are limited to 1 KiB, unknown
JSON fields and trailing JSON are rejected. Errors have a plain-text body:
400 for invalid commands or failed mutations, 503 for unavailable status,
404 for unknown routes, 405 for incorrect methods. Clients have a five-second
timeout. There are no notifications in v1; refresh status when needed.

```sh
curl --unix-socket /run/alphactl/control.sock http://localhost/v1/status
```
