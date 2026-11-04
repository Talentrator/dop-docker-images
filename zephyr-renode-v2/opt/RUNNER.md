# zr-scenario: events and checks

`zr-scenario run` (in the box) and `zr-scenario grade` (in the grader, as root) build a Zephyr project
the same way and run it on Renode against scenarios. This file lists every scenario event and check:
its JSON, one example, what it reads from the simulated hardware, and its limits. `zr-replay` (the
step-list replay tool) and `zr-record` (the author's session recorder) are described at the end.

Rules that hold for all of it:

- **Checks read the simulated hardware**: CAN frames on the hub, pin levels, instruction counts,
  CPU resets, the built image. The console is read only by `uart_match` and `no_uart_match`, and
  only for values that depend on a hidden input (see there).
- **Time is simulated time from power-on**, in seconds. Events are placed on a 1 us grid and applied
  with the emulation paused at that instant (the runner splits the run into `emulation RunFor`
  pieces). Recorded times (frames, pin edges, resets, console characters) are stamped inside Renode
  with the virtual time of the thread that caused them; a firmware's response is stamped to within
  about 1 us.
- **Renode counts instructions, not cycles.** nucleo_f767zi runs 462 M instructions per simulated
  second; there are no wait states, caches or bus contention, and I2C or SPI transfers take no time.
  Timing limits stay at the millisecond level. Instruction counts, flash and RAM are exact.
- **Board details live in zr-task.json** (platform, console, CAN buses, sensors, pins, ADC inputs,
  extra peripherals), so a scenario names a pin or a sensor and the same scenario shape works on
  another board by changing the task file only.
- **A board's devicetree fix.** Where Zephyr's board file disagrees with the real board, the image
  carries a fix next to the board's platform file (`/opt/zephyr-v2/renode/boards/<board>.overlay`, `/`
  as `_`), and every build for that board applies it before the task's locked overlay and again after
  the project's own. Today one board has one: stm32f072b_disco, whose user button is active high (Zephyr
  v4.4 says active low).
- **Sensor models: use the patched copies** where one exists, each in `/opt/zephyr-v2/renode/` (add it
  to `includes`): `Sensors.LIS2DW12Fixed` (`LIS2DW12Fixed.cs`: FIFO burst reads, data-ready),
  `Sensors.AS6221Fixed`, `Sensors.IIS2MDCFixed` and `Sensors.ICP_101xxFixed` (`AS6221Fixed.cs`,
  `IIS2MDCFixed.cs`, `ICP101xxFixed.cs`: multi-byte reads on I2C controllers that fetch one byte at a
  time, as stm32f4_disco's and nrf52840dk's do). Each file's header says what changed and why.
- Every check has a `name` and a `group` (default: the scenario's `group`, else `main`). A group
  scores the share of its checks that pass; the reward is the lowest group; a strict pass needs every
  check. No build: reward 0. A check or event the runner does not know, a pin or sensor the task file
  does not declare, or a Monitor command Renode refuses is a harness error (exit 2, no reward).

## Task file (zr-task.json)

| Key | Example | Meaning |
|---|---|---|
| `board`, `platform`, `console` | `"nucleo_f767zi"`, `"/opt/zephyr-v2/renode/boards/nucleo_f767zi.repl"`, `"usart3"` | west board, Renode platform file, console UART. Take all three, and `includes`, from the board's capability list (`boardcheck/results/<board>.json`, `renode` and `console`): those are the files the board check ran |
| `includes` | `["/opt/zephyr-v2/renode/STMCANZephyr.cs", "/opt/zephyr-v2/renode/boards/STM32_TimerZephyr.cs", ...]` | C# files loaded first. The runner adds `GPIORecorder.cs` and `ZRScenarioTools.cs` itself when a scenario needs them |
| `cpu` | `"sysbus.cpu"` (default) | the CPU whose instructions are counted |
| `can` | `["sysbus.can1"]` | CAN controllers; bus `i` gets hub `canHub<i>` and a recorder |
| `sensors` | `[{"name": "accel", "decl": "Sensors.LIS2DW12 @ i2c1 0x19", "path": "sysbus.i2c1.accel", "feed": "FeedAccelerationSamplesFromRESD"}]` | sensor models added to the platform |
| `peripherals` | `[{"name": "iwdg", "decl": "Timers.STM32_IndependentWatchdog @ sysbus 0x40003000 { frequency: 32000 }"}]` | other models the platform file lacks, added after it: for example a watchdog on a board file without one. nucleo_f767zi's board file already has `iwdg`, and adding a model twice is an error |
| `pins` | `{"led": {"port": "sysbus.gpioPortB", "pin": 0}, "button": {"port": "sysbus.gpioPortC", "pin": 13, "active": "low"}, "door": {"port": "sysbus.gpioPortE", "pin": 2, "idle": 0}}` | named pins. `active` marks a button and its pressed level; `idle` is the level an input starts at. A button starts released |
| `adcs` | `{"pot": {"path": "sysbus.adc1", "channel": 0}}` | named ADC inputs |
| `copy_in` | `["Kconfig", "dts/bindings"]` | opt-in: the app's `Kconfig` file and `dts/bindings/` cross into the build too (default: only `src/`, `prj.conf`, `app.overlay`). Nothing else may be listed. `run` and `grade` apply the same list |
| `feed_at_s`, `seed` | `0.1`, `1` | when traces start feeding (after the drivers set an output rate); Renode's seed |

## Scenario file

```json
{"name": "door", "group": "door", "duration_s": 1.0,
 "sensors": {"accel": {"trace": "shaking.csv", "rate_hz": 400, "start_s": 0.1}},
 "events": [ ... ], "checks": [ ... ]}
```

`sensors` plays a CSV (x,y,z in g) into a sensor through RESD from `start_s`; unchanged from Phase 1.

## Events

Each event has `type` and `at_s` (simulated seconds, within the scenario).

### button
```json
{"type": "button", "pin": "button", "at_s": 0.3, "hold_ms": 200, "bounce": {"count": 3, "ms": 2}}
```
Drives the pin to its `active` level at `at_s` and back after `hold_ms` (no `hold_ms`: it stays
pressed). With `bounce`, the contact opens and closes again `count` times, evenly over `ms`
milliseconds after each edge (2 x count extra edges), and settles `ms` after the first edge; the
release bounces the same way unless `"release_bounce": false`. Example above: edges at 0.300000,
0.300333, ... 0.302000 (settled pressed), release at 0.500000 with 6 more edges to 0.502000.
Reads/writes: the GPIO port's input (`OnGPIO`), the level EXTI and the firmware see.
Limits: the pin is driven at the port, not through Renode's `Button` model: `Button.Press` from the
Monitor takes effect one time quantum late (a press at 0.5003 s landed at 0.5004 s), driving the
port lands on time. Bounce is evenly spaced, not random.

### gpio_in
```json
{"type": "gpio_in", "pin": "door", "at_s": 0.4, "level": 1}
```
Sets an input pin's level. Limits: after a CPU reset the port's input levels return to their reset
state (0) unless a Renode model drives the pin (the user button's model does); the runner does not
drive them again.

### can_send
```json
{"type": "can_send", "bus": 0, "at_s": 0.4, "id": "0x200", "data": "05", "ext": false}
```
A frame from an external node: handed straight to the bus's controller (`InjectFrame`, in
ZRScenarioTools.cs), which filters it and raises its receive interrupt as for a frame off the wire.
It appears in the frame list as sent by `external`, which every CAN check leaves out, so an injected
request never counts as the firmware's answer. Limits: up to 8 data bytes (classic CAN), no remote
frames, no CAN FD. Renode's `CANHub` cannot carry it: the hub names every sender through the
machine it belongs to, and an external node has none, so the frame does not go through the hub and
the hub's recorder file does not show it (the runner adds it to the list itself).

### console_in
```json
{"type": "console_in", "at_s": 0.4, "text": "12\r\n"}
```
Characters arrive on the console UART's receiver at `at_s` (`WriteChar` each; `"hex": "0d0a"` instead
of `text` for raw bytes; `"uart": "sysbus.usart2"` for another UART). They queue in the UART model,
so a firmware that reads one at a time gets them all. Limits: all characters arrive at the same
instant, not at a baud rate.

### sensor_set
```json
{"type": "sensor_set", "sensor": "accel", "at_s": 0.4, "property": "AccelerationX", "value": 1.0}
```
Sets a property of a sensor model (`sysbus.i2c1.accel AccelerationX 1`): the next reading the
firmware takes returns it. Property names are the model's (LIS2DW12: `AccelerationX`/`Y`/`Z` in g,
`Temperature`; HS3001: `Temperature`, `Humidity`; NOTES.md lists the parts that read). Limits: on a
sensor that is also playing a trace, the trace overrides the value at its next sample.

### sensor_freeze
```json
{"type": "sensor_freeze", "sensor": "accel", "at_s": 0.5}
```
The sensor keeps answering, but its reading stops changing: every trace sample due at or after
`at_s` repeats the last one before it. Needs a sensor with a trace in this scenario.
Not offered: a sensor that **stops answering** on the bus. Taking the LIS2DW12 off I2C1 mid-run
(`sysbus.i2c1 Unregister ...`) works in Renode, but its STM32F7 I2C model then raises no NACK for
the missing address, and Zephyr's driver waits forever: the firmware hangs at its next read (seen:
no output for 2 s, no driver timeout), where the real chip would NACK at once and the driver return
an error. A correct firmware would be marked wrong, so the event waits for a patched I2C model.

### adc_set
```json
{"type": "adc_set", "adc": "pot", "at_s": 0.4, "value": 3000}
```
From `at_s` the ADC input reads `value` (raw counts) on every conversion (`FeedSample value channel
-1` on Renode's STM32_ADC). Put one at `at_s: 0` for the starting value. Limits: raw counts, not
volts; one value per input at a time.

## Checks

### Pin checks (GPIORecorder.cs)

The recorder hooks each declared pin's line on its GPIO port and writes every level change with its
simulated time. On an STM32 port that line carries the pin level however it is driven (the firmware
writing ODR or BSRR, or an input from outside), what a logic analyser on the pin would show. Every
pin in the task file is recorded in a scenario that uses pins.

| Check | Example | Passes when |
|---|---|---|
| `pin_level` | `{"type": "pin_level", "pin": "led_red", "at_s": 0.5, "level": 1}` | the pin's level at `at_s` (after any edge at exactly `at_s`) is `level` |
| `pin_edge_deadline` | `{"type": "pin_edge_deadline", "pin": "led_blue", "edge": "rising", "t0_s": 0.3, "within_ms": 2, "early_ms": 1}` | the first `edge` (`rising`, `falling`, `any`) at or after `t0_s - early_ms` comes by `t0_s + within_ms` |
| `pin_edge_count` | `{"type": "pin_edge_count", "pin": "led_green", "edge": "rising", "from_s": 0.1, "to_s": 1.0, "count": 5}` | the number of edges in `[from_s, to_s)` is `count`, or within `min_count` / `max_count` |
| `no_pin_edge` | `{"type": "no_pin_edge", "pin": "led_red", "from_s": 0.5, "to_s": 1.0}` | no edge (of `edge`, default any) in the window |
| `pin_pwm` | `{"type": "pin_pwm", "pin": "led_green", "from_s": 0.2, "to_s": 0.8, "period_ms": 10, "period_tol_ms": 0.2, "duty": 0.3, "duty_tol": 0.02}` | every full cycle (rising edge to rising edge) in the window is within the period tolerance, and its high share within the duty tolerance; at least (window / period - 1) cycles |

Limits: edges come from the GPIO port model; a peripheral that drives a pin through its alternate
function (a hardware timer's PWM output) only shows if its Renode model drives the port's line. The
F767 platform file has no TIM1 to TIM5 models, so hardware PWM is not expected to work there (not
tested); a software PWM from a timer interrupt does (tested, `tests/runner/pin_pwm`). Duty is the
share of the cycle the pin is high, whatever the LED's polarity.

### instructions
```json
{"type": "instructions", "from_s": 0.5, "to_s": 1.0, "max": 1000000}
```
Instructions the CPU executed in the window (`ExecutedInstructions` read at both ends), at most
`max` (and at least `min`, if given). Exact and repeatable. A CPU in WFI executes nothing, so an
idle firmware costs only its wake-ups: measured on nucleo_f767zi, 242 instructions in 100 ms of
`k_sleep`, and 23.05 M in 50 ms of `k_busy_wait` (462 MIPS). Limits: instructions, not cycles (a
divide or a flash wait costs one); Renode restarts the count at a CPU reset, so a reset inside the
window fails the check.

### flash_size, ram_size
```json
{"type": "flash_size", "max_bytes": 40000}
{"type": "ram_size", "max_bytes": 16384}
```
From the built ELF's program headers, not the simulation. flash = bytes stored in the image (every
loadable segment's file size: code, read-only data, initial values of .data); ram = bytes the
image takes in RAM (loadable segments copied to RAM or not in the file: .data, .bss, noinit, stacks,
heap). On a test image: flash 29536 B (the linker's "Memory region" table: 29536 B), ram 4924 B (the
linker: 4928 B, which also counts a 4-byte alignment gap). Read from the image the grader copied
after the build, never from the build log (a firmware can print anything into a log).

### cpu_resets
```json
{"type": "cpu_resets", "from_s": 0.3, "to_s": 0.6, "count": 1}
```
Machine resets in the window (a watchdog, SYSRESETREQ, `sys_reboot`), from Renode's reset event
(ZRScenarioTools.cs). `count`, or `min_count` / `max_count`; with none of them it expects 0. After
a reset the image boots again (the runner sets Renode's `reset` macro to reload it; without one the
CPU took its vector table from address 0 and locked up). The test watchdog (100 ms, fed every 50 ms
for 250 ms) reset at 0.3503 s and 0.7006 s and the firmware booted each time.

### uart_match, no_uart_match
```json
{"type": "uart_match", "pattern": "SQ=144\\b", "from_s": 0.4, "to_s": 0.8,
 "hidden_input": "the number typed at 0.4 s (12)"}
```
The characters the firmware sent on the console UART in the window (stamped as they leave, so a
window can start at the hidden input) searched with a Python regular expression: at least one match
(`count`, `min_count`, `max_count` as for pin edges), or none for `no_uart_match`.
**Allowed only for values that depend on hidden inputs.** Checks read the hardware; a firmware that
prints the expected value must not pass. A printed value counts only where the firmware could not
know it without doing the work (the square of a number it was sent, a reading of a hidden trace),
never for "prints ALERT". The runner refuses a console check without a `hidden_input` naming that
input (harness error); a reviewer checks that it really is hidden. `no_uart_match` passes on silence,
so pair it with a check that something was printed.

### CAN checks (Phase 1, unchanged)

`can_frame`, `no_can_frame`, `can_deadline`, `can_data`, `can_period`; frames sent by `external`
(including `can_send` events) are left out of all of them.

## Proven both ways

`tests/runner/run_all.sh` grades, for every event and check above, a firmware that passes it and one
that fails it, under `zr-scenario grade` (root, hidden scenarios 0700, build as `zbuild`), after a
control run (impact-alert's gold, 1.0 strict). The fail firmware must fail exactly the check under
test and pass the rest. `--mutants` also runs two broken runners the cases must catch: one whose new
checks always pass (caught by all 17 cases whose check under test is new), one that drops every event (caught by
all 9 cases with events). Last run: every outcome held, 329 s on 3 containers.

## zr-replay: the step-list replay tool

```
zr-replay STEPS.md --workdir /workdir/tcu --user zephyr --files <author's files> \
          --out replay-trajectory.jsonl --report replay-report.json
```

Proposed step-list format (Markdown, version 1): each `## heading` is a step, the text under it the
author's note (it becomes the reasoning of the step's first call), each fenced block one call:

````
## Run the visible scenarios again
Both pass: the alert about 1 ms after t0.

```sh
zr-scenario run --project /workdir/tcu
```
- expect line: ^score 1\.000 .*strict pass: True
- expect no line: ^FAIL

```c file=src/impact.c src=gold/src/impact.c
```
````

A `sh` block runs as written; a block with `file=PATH` writes that file (inline content, or `src=`
relative to `--files`) as a heredoc call, the way models write files. After a block: `expect exit N`
(default 0, `any` to skip), `expect line: REGEX`, `expect no line: REGEX`. Each call runs as DOP runs
a model's: a fresh login shell of the task user, `cd <workdir> && <command>`. Output: a trajectory
JSONL in DOP's shape (a `model` entry with the `bash` tool call, a `tool` entry with the real output,
exit code and duration; a closing `submit`), and a report of which expectations held. Exit 0 when
every call matched. Example: `tests/runner/replay/impact-alert.steps.md`.

## zr-record: recording an author's solution

```
zr-record [-o recording.jsonl] [--project /workdir/tcu] [--user zephyr] [--force]
zr-record export recording.jsonl > steps.md
```

An author solves the task in the task's box (locally, with the published image) and `zr-record` writes
the session as `recording.jsonl`, the recording form of DOP's steps format, which DOP replays in Verify.
It is a read-and-run loop, not a hooked shell: each line typed is one command, run as DOP runs a model's
(a fresh login shell of the task user, `cd <project> && <command>`), so `cd` and variables do not carry
over, as for the model. Output shows live. A line ending in `\`, a line that leaves a quote open and a
heredoc (`cat > f <<'EOF'` ... `EOF`) read on. Commands get no stdin and no terminal, so edit in a second
terminal (`docker exec -it <box> bash`, `vi` is there) or an editor attached to the container.

Lines starting with `#` are not run:

| Line | Writes |
|---|---|
| `#why TEXT` | a `note` line: the reasoning for what comes next |
| `#step TITLE` | a `step` line: what follows, up to the next `#step`, is one step |
| `#sync` | nothing itself: picks up editor changes now (this also happens at every other line) |
| `#end` | stops (so does Ctrl-D or the end of input) |

The recording, one JSON object per line (`t`: seconds since the start; a command's `t` is when it
started):

```
{"t": 0.0, "type": "command", "command": "zr-scenario run", "output": "...", "exit_code": 0, "seconds": 41.2}
{"t": 95.4, "type": "file", "path": "src/impact.c", "content": "..."}
{"t": 96.0, "type": "delete", "path": "src/old.c"}
{"t": 97.1, "type": "note", "text": "why I did the next part"}
{"t": 97.1, "type": "step", "title": "Add the impact detector"}
```

Editor changes: whenever a line is read, and at the end, `zr-record` compares the project's files with
how it last saw them. A changed text file becomes a `file` line with its whole new content, a removed
file a `delete` line, in path order, ahead of the line just typed. A file changed by a command is not
written as a `file` line, since replaying the command makes the same change; the recorder names such
files on the terminal. So save editor changes before running the next command: a file saved while a
command runs counts as that command's change. Not compared: `build/` and any folder holding a
`CMakeCache.txt`, `.git/`, caches, editor swap and backup files, and the recording itself. A binary
file, a file over 1 MB (`--max-file-bytes`) or a symbolic link that changes outside the loop is not
recorded: the recorder prints a one-line warning and writes no line, since a `note` is the author's
reasoning in the trajectory. Verify's fill from the answer key names such a file. Removing a file that
was made outside the loop and never recorded writes no `delete` line either.

A command interrupted with Ctrl-C is not recorded (a replay would run it to the end); any file it
changed is recorded as a `file` line instead. A command still running after `--timeout` (900 s, as
zr-replay) is stopped and recorded with exit code 124. At the end the recorder warns when the
recording lacks `zr-scenario run` before the first change or after the last: Verify requires both.

`zr-record export` writes the recording as the version 1 step list above, so `zr-replay` replays it
today: a `step` line starts a step, notes become its text, a command becomes a `sh` block with `expect
exit <recorded exit code>` (the recorded output is not an expectation), a `file` line a `file=PATH`
block with its content, a `delete` line `rm -f`. A file a block cannot carry byte for byte (no final
newline, a line starting with three backticks, the heredoc marker, an unusual path) is written from
base64 instead. Grouping, which only sets titles and texts: before the first `step` line each command is
its own step titled by the command, and a run of `file` and `delete` lines is one step ("Edit
src/impact.c"); a note belongs to the step it was written in while that step has no calls yet,
otherwise to the step of the next call or `step` line.

Proven by `tests/record/run.sh` (the zephyr-v2 repo): a scripted session in the impact-alert box with
edits made from outside the loop, every line checked against the format, the export replayed by
`zr-replay` in a fresh box with every expectation held, and the replayed project graded the same as the
recorded one (1.0, strict). With `--mutant` it runs a recorder whose editor-change detection is off, which
the test must catch. Last run (4 Nov, zephyr-renode-v2:p3 with this folder mounted): 17 of 17 checks
held in 120 s; the mutant failed 9 of 17 (its replayed project graded 0.0).
