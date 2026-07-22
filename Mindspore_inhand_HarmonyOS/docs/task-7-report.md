# Task 7: Text Translation Worker Repair

## Result

The default Harmony translation service now uses `TranslationWorkerClient`. The UI thread extracts and verifies the packaged archive, starts one `TranslationWorker`, and exchanges only initialization and translation messages. The Worker owns the tokenizer, all three MindSpore Lite models, the translation session, and the FIFO queue.

## Root cause and repair

The API24 Worker initially loaded models without inputs. The direct cause was chunked `fileIo.read` calls that reused `offset: 0`, repeatedly copying the first MiB of each model. OpenHarmony `fileIo` offsets are absolute file positions, so both readers now pass `offset: copied`. The Worker also retains each model `ArrayBuffer` while its native model is alive.

The archive native SHA finalization was repaired to use the API-allocated digest blob and free it after copying, so archive verification no longer reads an invalid digest buffer.

## Emulator evidence (API24 x86_64)

- Production `pages/FeatureRuntimePage` opened through the normal entry card.
- Typed `Please close the door and open the window.` produced visible Chinese output; the run button was disabled during the first asynchronous initialization.
- Typed `请将门关上然后打开窗户。` produced visible English output.
- Worker evidence before diagnostic cleanup: `initialized graphs=3 initCount=1`; later requests returned successful results without a second initialization.
- First worker initialization took about 8.4 seconds; the following translation completed in about 0.76 seconds.
- The system photo picker opened from the image button. HDC was denied write access to `/storage/media/100/local/files/Pictures`, and the emulator's `mediatool` provides query/receive/delete only, not import. No claim is made that a fixture was selected through the protected picker.
- The camera action remained non-blocking; the photo picker service reported `cameraAble=true`, but no physical camera outcome is claimed for the emulator.

## OCR device evidence

`aa test -b com.yuhaofeng.mih -m entry_test -s unittest OpenHarmonyTestRunner -s class OcrNativeTest -w 90` passed with 5/5 cases. The permanent suite now runs English, Chinese, Chinese sentence, and multiline fixtures plus the failure-visibility contract. The Chinese sentence fixture produced `青把门关上然后打开窗户` with CER `0.090909...`, within the 0.10 limit.

## Evidence boundary and lifecycle hardening

The OCR device suite is OCR-runtime evidence only. The test HAP injects the legacy translation bundle factory because it cannot load the production Worker URI across the HAP boundary; it is not evidence of OCR flowing into the production Worker. Protected-media import limitations also mean no production picker OCR-to-Worker end-to-end claim is made.

Leaving the runtime page invalidates the runtime service session, which starts asynchronous `DefaultAiService.stop()` cleanup; it is not awaited by the page callback. That cleanup stops the translation service and terminates its Worker. The client rejects pending work, clears request timers, detaches handlers, and uses a generation plus Worker-instance check so an old exit/error event cannot affect a replacement Worker. `TranslationWorkerClientTest` covers idempotent termination, old-Worker exit after replacement, and both initialization and translation `postMessage` failures. The Worker rejects malformed requests and a duplicate initialization request.

## Final semantic audit and decoder correction

The final API24 production-page audit exposed a decoder cache-mask defect: `hello world` rendered as `地狱地狱世界世界`. The exported step graph concatenates the fixed 127-slot history with the current key at mask slot 127. The ArkTS runner instead enabled history through `position` and left slot 127 disabled. It now enables exactly history slots `[0, position)` plus slot 127. A LocalUnit regression asserts every one of the 128 mask values at consecutive decode positions.

With the corrected mask, the same production Worker renders `hello world` as the finite, non-repeating `地狱世界`; it also rendered `Keep this report confidential until Monday.` as `保持此报告保密直到星期一。` and `请把门关上然后打开窗户` as `Please close the door and open the window`. This is decoder-correctness evidence, not a claim that the remaining `hello world` meaning is acceptable.

A bounded search diagnostic ruled out a standard beam-search-only repair. For `Hello world`, the three prefill branches completed as follows: ` Hello世界` at raw/average log probability `-4.27780/-1.06945`, `Hello世界` at `-3.15116/-1.05039`, and the semantically correct `你好世界` at `-4.07928/-1.35976`. Both raw and length-normalized scoring select the incorrect `Hello世界` branch. Lowercase input with a period still rendered `地狱世界。`, so sentence case and punctuation normalization do not resolve the defect. The temporary diagnostic was removed after capture.

The packaged authorization is explicit: `local-learning-authorization-v1.json` lists `manual-quality-gate-not-passed` and `local-learning-only-not-production-approved`, with `productionPromotionAllowed: false`. Text Translation therefore remains blocked at the model-quality boundary. Production completion requires a replacement or retrained model with a passing sentence-level quality gate and production approval; hard-coded phrase replacement is not accepted as a repair.

## Remaining scope

The tracked package contains both arm64-v8a and x86_64 payloads. API24 x86_64 emulator evidence is recorded above; no arm64 physical-device test is claimed. Translation model replacement/retraining and production quality approval remain open.
