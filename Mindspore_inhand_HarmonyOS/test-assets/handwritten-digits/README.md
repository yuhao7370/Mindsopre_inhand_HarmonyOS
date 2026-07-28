# Handwritten MNIST test fixtures

These ImageGen outputs are desktop-only test assets. They are deliberately outside `entry/`, so they are not packaged into a HAP. `scripts/validate-mnist-test-assets.py` extracts `artifacts/lenet_mnist.mindir` from the College tutorial ZIP into a temporary directory, mirrors `HandwrittenDigitPreprocess.ets`, and runs installed desktop MindSpore.

<!-- mnist-test-assets-manifest
[
  {
    "file": "digit-2.png",
    "expected": 2,
    "predicted": 2,
    "confidence": 0.9709977507591248,
    "dimensions": "1024x1536",
    "sha256": "16A2868156CA7D0F9DF72C6C8A412C621BD8634F29F651DCCE5532C9B3E16622",
    "source": "C:\\Users\\27377\\.codex\\generated_images\\019f7fd1-7f4c-7f23-90a6-5a0604ebdc4f\\call_4VOAG7Jazwi0IAvt1LIMDwyb.png",
    "prompt": "realistic close-up of one handwritten Arabic digit 2, thick black felt-tip on near-white paper, upright centered complete generous margins, natural stroke, soft lighting, paper texture, high contrast, front-facing, exactly one digit, no other writing, objects, or watermark",
    "logits": [-0.6373109817504883, 0.5657343864440918, 5.504332542419434, 0.08675968647003174, -1.2957314252853394, -1.6566522121429443, -1.25086510181427, 0.3579115867614746, 0.47560638189315796, -1.7709366083145142]
  },
  {
    "file": "digit-7.png",
    "expected": 7,
    "predicted": 7,
    "confidence": 0.8224323987960815,
    "dimensions": "1024x1536",
    "sha256": "6F6B137F81272AFDFCEF5942AFD43D8D605F93A14556DA3E05C825C42BFEA393",
    "source": "C:\\Users\\27377\\.codex\\generated_images\\019f7fd1-7f4c-7f23-90a6-5a0604ebdc4f\\call_RYgbnCvV5VT68treuN2mbGlU.png",
    "prompt": "realistic close-up of one handwritten Arabic digit 7, thick black felt-tip on near-white paper, upright centered complete generous margins, natural stroke, soft lighting, paper texture, high contrast, front-facing, exactly one digit, no crossbar, no other writing, objects, or watermark",
    "logits": [-1.2974834442138672, 1.7234493494033813, 0.6159562468528748, 1.1087175607681274, -0.9280009865760803, -1.2296525239944458, -2.2486863136291504, 4.076225757598877, -0.3264014720916748, -0.8029932975769043]
  },
  {
    "file": "digit-9.png",
    "expected": 9,
    "predicted": 9,
    "confidence": 0.9926242232322693,
    "dimensions": "1254x1254",
    "sha256": "9A4B32923B0ACA332A59183FCBF2A2354BBC36F23DE3A4CB2E9F9FDB8864CFCD",
    "source": "C:\\Users\\27377\\.codex\\generated_images\\019f7fd1-7f4c-7f23-90a6-5a0604ebdc4f\\call_uN0XpYZfRBEt8hmLUWUN2Oc3.png",
    "prompt": "realistic close-up of one handwritten Arabic digit 9, thick black felt-tip on near-white paper, upright centered complete generous margins, natural stroke, soft lighting, paper texture, high contrast, front-facing, exactly one digit, closed loop plus stem, no other writing, objects, or watermark",
    "logits": [-2.712346076965332, -2.9577760696411133, -1.909438967704773, 0.7327322363853455, 3.727569103240967, 0.5729476809501648, -5.628519535064697, 0.29979461431503296, 1.193636178970337, 8.821175575256348]
  }
]
-->

The manifest above is the fixture contract: source, complete generation prompt, image dimensions, SHA-256, expected label, and the recorded desktop MindIR prediction/confidence. Regenerate a fixture rather than editing it to influence a prediction.
