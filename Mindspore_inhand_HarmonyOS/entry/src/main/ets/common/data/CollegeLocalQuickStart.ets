import { CollegeItem, collegeItems } from './CollegeCatalog';

export interface CollegeTutorialCodeBlock {
  readonly title: string;
  readonly code: string;
}

export interface CollegeLocalQuickStartSection {
  readonly id: string;
  readonly step: string;
  readonly title: string;
  readonly objective: string;
  readonly paragraphs: Array<string>;
  readonly codeBlocks: Array<CollegeTutorialCodeBlock>;
  readonly measuredResult: string;
}

export const visibleCollegeItems: CollegeItem[] =
  collegeItems.filter((item: CollegeItem) => item.id !== 'quick' && item.id !== 'faq');

export const collegeLocalQuickStartSections: Array<CollegeLocalQuickStartSection> = [
  {
    id: 'environment',
    step: '01',
    title: '先看任务和环境',
    objective: '先确认这台电脑能跑什么，再用 MindSpore 做一遍经典的手写数字识别。',
    paragraphs: [
      '这套流程已经在本机跑过一遍：训练、评估和导出都留下了实际结果。电脑是 Windows 11，装有 Python 3.11.7、MindSpore 2.5.0（CPU）、scikit-learn 1.3.2、NumPy 1.26.4 和 Pillow 12.1.1。',
      '本机没有真实 MNIST 的 IDX 文件。为了离线也能跑，我们换成 scikit-learn 自带的 digits：1797 张 8×8 灰度手写数字图。任务还是识别 0 到 9，不过后面看到的准确率只属于 digits，不是 MNIST。',
      'PyTorch 2.6.0 本身能用，torchvision 0.22.0 却和它对不上，导入时会报 operator torchvision::nms does not exist。问题出在环境版本，不在 MindSpore。这里直接从 scikit-learn 读数据，也省掉了下载。'
    ],
    codeBlocks: [
      {
        title: '环境检查',
        code: 'python --version\npython -m pip show mindspore torch torchvision scikit-learn numpy pillow\npython -c "import mindspore as ms; print(ms.__version__, ms.get_context(\'device_target\'))"'
      },
      {
        title: '从头跑一遍',
        code: 'python docs/tutorials/mindspore-digits-lenet.py --epochs 20 --batch-size 64 --learning-rate 0.002 --output-dir .tmp-college-tutorial/verified-artifacts'
      }
    ],
    measuredResult: '环境是 Python 3.11.7、MindSpore 2.5.0，跑在 CPU 上。脚本和运行记录都放在 docs/tutorials 目录，断网也能重新执行。'
  },
  {
    id: 'data',
    step: '02',
    title: '准备本地数据',
    objective: '先把本地 digits 整理成 LeNet 能吃的格式，再切出固定的训练集和测试集。',
    paragraphs: [
      'load_digits() 会给出 1797 张图片，像素范围是 0–16，标签是 0–9。脚本先把像素转成 8-bit 灰度，再用 Pillow 放大到 28×28，最后按 (x - 0.5) / 0.5 归一化到 [-1, 1]。',
      '送进模型的是 float32 NCHW [N, 1, 28, 28]，标签用 int32。我们固定随机种子 42，再按标签做 80/20 分层切分，最后拿到 1437 张训练图和 360 张测试图。',
      'NumpySlicesDataset 可以直接接收这些内存数组。训练集会打乱，测试集保持原顺序；batch 大小是 64，最后不满 64 的一批也保留。'
    ],
    codeBlocks: [
      {
        title: '缩放与归一化',
        code: 'pixels = np.rint(image / 16.0 * 255.0).astype(np.uint8)\ncanvas = Image.fromarray(pixels, mode="L").resize((28, 28), Image.Resampling.BILINEAR)\nnormalized = np.asarray(canvas, dtype=np.float32) / 255.0\ninput_tensor = ((normalized - 0.5) / 0.5)[None, :, :]'
      },
      {
        title: '切分与批处理',
        code: 'train_x, test_x, train_y, test_y = train_test_split(\n    images, labels, test_size=0.2, random_state=42, stratify=labels\n)\ntrain_data = ds.NumpySlicesDataset(\n    {"image": train_x, "label": train_y.astype(np.int32)}, shuffle=True\n).batch(64, drop_remainder=False)'
      }
    ],
    measuredResult: '原图是 [1797, 8, 8]，处理后是 [1797, 1, 28, 28]。其中 1437 张拿来训练，360 张留作测试，整个过程不用下载数据。'
  },
  {
    id: 'network',
    step: '03',
    title: '搭好 LeNet 网络',
    objective: '照着熟悉的 PyTorch 思路，在 MindSpore 里搭一个十分类网络。',
    paragraphs: [
      '结构很经典：两组卷积、ReLU 和最大池化负责提取特征，后面接 120、84、10 三层全连接，最后输出十类 logits。整个网络有 44,404 个可训练参数。',
      '如果写过 PyTorch，这里很好对照：nn.Module 换成 nn.Cell，forward() 换成 construct()；DataLoader 对应 mindspore.dataset 和 batch()；交叉熵与 Adam 也都有直接对应的类。',
      '这里用的是 ReLU 和 MaxPool，所以更准确地说，它是现代 LeNet-5 风格网络，和 1998 年原版不完全一样。拿它入门卷积分类正合适。'
    ],
    codeBlocks: [
      {
        title: 'MindSpore 网络',
        code: 'class LeNet5(nn.Cell):\n    def __init__(self):\n        super().__init__()\n        self.features = nn.SequentialCell(\n            nn.Conv2d(1, 6, 5, pad_mode="valid"), nn.ReLU(), nn.MaxPool2d(2, 2),\n            nn.Conv2d(6, 16, 5, pad_mode="valid"), nn.ReLU(), nn.MaxPool2d(2, 2)\n        )\n        self.classifier = nn.SequentialCell(\n            nn.Flatten(), nn.Dense(16 * 4 * 4, 120), nn.ReLU(),\n            nn.Dense(120, 84), nn.ReLU(), nn.Dense(84, 10)\n        )\n\n    def construct(self, x):\n        return self.classifier(self.features(x))'
      },
      {
        title: '损失与优化器',
        code: 'loss_fn = nn.SoftmaxCrossEntropyWithLogits(sparse=True, reduction="mean")\noptimizer = nn.Adam(network.trainable_params(), learning_rate=0.002)\nmodel = ms.Model(network, loss_fn=loss_fn, optimizer=optimizer,\n                 metrics={"accuracy": nn.Accuracy()})'
      }
    ],
    measuredResult: '网络已经在 MindSpore 2.5.0 CPU 上完成前向、反向和参数更新。输入是 float32 NCHW [N,1,28,28]，输出是 float32 [N,10]。'
  },
  {
    id: 'training',
    step: '04',
    title: '跑训练，看结果',
    objective: '训练 20 轮，每轮都看一次测试准确率，再比较两次运行为什么会有小幅波动。',
    paragraphs: [
      '设置很简单：batch size 64，优化器用 Adam，学习率 0.002，一共训练 20 轮，dataset_sink_mode=False。每轮结束后，马上用 360 张测试图算一次准确率。',
      '第一次运行从第 1 轮的 80.28% 涨到第 20 轮的 98.61%，最终和最好成绩都是 98.61%，训练用了 4.344 秒。把脚本移到文档目录后又跑了一遍，最终是 96.94%，最好是 98.33%，耗时 4.497 秒。',
      '两次结果都过了 96%，但并不完全相同。CPU 算子的细微差异会带来这种波动，所以看趋势比盯着某个最高值更有意义。别忘了，这些数字只对应 digits 测试集。'
    ],
    codeBlocks: [
      {
        title: '训练与评估循环',
        code: 'for epoch in range(1, 21):\n    model.train(1, train_data, dataset_sink_mode=False)\n    metrics = model.eval(test_data, dataset_sink_mode=False)\n    print(epoch, metrics["accuracy"])'
      },
      {
        title: '第一次运行的日志',
        code: 'epoch=01 test_accuracy=0.8028 seconds=0.348\nepoch=06 test_accuracy=0.9667 seconds=0.212\nepoch=14 test_accuracy=0.9833 seconds=0.208\nepoch=20 test_accuracy=0.9861 seconds=0.199'
      }
    ],
    measuredResult: '第一次跑到 98.61%，用了 4.344 秒；重跑最终 96.94%、最好 98.33%，用了 4.497 秒。两次都完成了 20 轮，也都没有下载数据。'
  },
  {
    id: 'export',
    step: '05',
    title: '导出模型，认清边界',
    objective: '保存 CKPT、导出 MindIR，再把模型读回来对一次结果，同时弄清它为什么还不能直接塞进 HarmonyOS 应用。',
    paragraphs: [
      '训练完成后先存 lenet_digits.ckpt，再用一个全零的 [1,1,28,28] float32 张量导出 MindIR。第一次读回模型时还停在 PYNATIVE_MODE，结果直接报错；切到 GRAPH_MODE 后就跑通了。',
      '我们固定拿一张标签为 5 的测试图做检查。训练网络预测 5，读回来的 MindIR 也预测 5，两份 logits 的最大绝对差是 0.0。这说明桌面导出没有改动这张图的计算结果。',
      '这里要注意：HarmonyOS 应用现在加载的是 MindSpore Lite .ms，自定义模型入口还固定要求 float32 NHWC [1,224,224,3]。刚导出的却是桌面 MindIR，输入为 float32 NCHW [1,1,28,28]。格式和张量都对不上，改个扩展名也没用。',
      '目前只走到了桌面 MindIR。仓库和 PATH 里都没有 converter_lite，Lite 转换、API 24 模拟器加载和 arm64 真机推理还没做。要接进应用，还得先转成 MINDIR_LITE，再补齐灰度化、缩放、归一化和 NCHW 排列，最后拿同一批样本核对数值。'
    ],
    codeBlocks: [
      {
        title: '保存与导出',
        code: 'ms.save_checkpoint(network, "lenet_digits.ckpt")\nms.export(network, Tensor(np.zeros((1, 1, 28, 28), np.float32)),\n          file_name="lenet_digits", file_format="MINDIR")'
      },
      {
        title: '回载验证',
        code: 'ms.set_context(mode=ms.GRAPH_MODE)\ngraph_network = nn.GraphCell(ms.load("lenet_digits.mindir"))\nexported_logits = graph_network(Tensor(test_x[:1])).asnumpy()'
      }
    ],
    measuredResult: 'CKPT 是 177,956 B，MindIR 是 188,389 B。样本标签、导出前预测和回载后预测都是 5，logits 最大差 0.0。Lite .ms 转换和 HarmonyOS 端侧运行还没做。'
  }
];

export function nextCollegeQuickStartExpandedId(currentId: string, selectedId: string): string {
  return currentId === selectedId ? '' : selectedId;
}
