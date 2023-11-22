import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  var title;

  MyHomePage({super.key, this.title});
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage>
    with SingleTickerProviderStateMixin {
  double width = 0;
  double height = 0;
  late CameraController controller;
  late AnimationController animationController;
  late Animation<double> photoAnimationButton;
  late final TextRecognizer textDetector;
  late final FaceDetector faceDetector;
  late final ObjectDetector imageLabeler;
  File _image = File('');
  String _recognizedText = '';
  bool _isDetectingFace = false;

  Future selectCam() async {
    List<CameraDescription> listCams = [];
    listCams = await availableCameras();
    print("lista de camaras ${listCams}");
    final CameraDescription firstCamera = listCams[0];
    controller = CameraController(
      firstCamera,
      ResolutionPreset.ultraHigh,
    );
    await controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            break;
          default:
            break;
        }
      }
    });
  }

  @override
  void initState() {
    selectCam();
    textDetector = GoogleMlKit.vision.textRecognizer();
    faceDetector = GoogleMlKit.vision.faceDetector();
    imageLabeler = GoogleMlKit.vision.objectDetector(options: ObjectDetectorOptions(
      mode: DetectionMode.single,
      classifyObjects: true,
      multipleObjects: false
    )); 
    animationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    photoAnimationButton = Tween(begin: 0.16, end: 0.21).animate(
        CurvedAnimation(
            parent: animationController,
            curve: const Interval(0, 0.5, curve: Curves.bounceInOut)));
    animationController.addListener(() {
      setState(() {});
    });

    super.initState();
  }

  @override
  void dispose() {
    textDetector.close();
    faceDetector.close();
    imageLabeler.close();
    super.dispose();
  }

  Future<void> _analyzeImage() async {
    final inputImage = InputImage.fromFile(_image!);
    final RecognizedText recognizedText =
        await textDetector.processImage(inputImage);
    final List<Face> faceDetection =
        await faceDetector.processImage(inputImage);
    final List<DetectedObject> imageRecognition =
        await imageLabeler.processImage(inputImage);

    setState(() {
      _isDetectingFace = faceDetection.isNotEmpty;
      print('faceDetection.isNotEmpty ${faceDetection.toString()}');
      inspect(faceDetection);
      inspect(recognizedText);
      inspect(imageRecognition);
      _recognizedText = recognizedText.text;
    });
  }

  Future<File?> cropImage(File originalImage, Rect boundingBox) async {
    // Decodifica la imagen original
    img.Image image = img.decodeImage(await originalImage.readAsBytes())!;

    // Convierte las coordenadas de la boundingBox a enteros
    int left = boundingBox.left.toInt();
    int top = boundingBox.top.toInt();
    int right = boundingBox.right.toInt();
    int bottom = boundingBox.bottom.toInt();

    // Asegúrate de que las coordenadas estén dentro de los límites de la imagen
    left = left.clamp(0, image.width);
    top = top.clamp(0, image.height);
    right = right.clamp(0, image.width);
    bottom = bottom.clamp(0, image.height);

    // Calcula las dimensiones del rectángulo a recortar
    int width = right - left;
    int height = bottom - top;

    // Recorta la imagen
    // img.Image croppedImage = img.copyCrop(image, left, top, width, height);

    // Guarda la imagen recortada en un archivo temporal
    File croppedFile = File(originalImage.path.replaceFirst('.png', '_cropped.png'));
    // await croppedFile.writeAsBytes(img.encodePng(croppedImage)!);

    return croppedFile;
  }


  @override
  Widget build(BuildContext context) {
    width = MediaQuery.of(context).size.width;
    height = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Stack(alignment: Alignment.center, children: [
        Center(
          child: controller.value.isInitialized
              ? Container(
                  height: MediaQuery.of(context).size.height,
                  width: MediaQuery.of(context).size.width,
                  child: CameraPreview(controller!))
              : const CircularProgressIndicator(),
        ),
        Positioned(
          bottom: (height * 0.0704) - (width * photoAnimationButton.value / 2),
          child: InkWell(
            onTap: () async {
              await animationController.play(
                  duration: const Duration(milliseconds: 200));
              await Future.delayed(const Duration(milliseconds: 50));
              await animationController.playReverse(
                  duration: const Duration(milliseconds: 100));
              final XFile xFile = await controller.takePicture();
              _image = File(xFile.path);

              await _analyzeImage();
            },
            child: Container(
              width: width * photoAnimationButton.value,
              height: height * photoAnimationButton.value,
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                shape: BoxShape.circle,
              ),
              child: Container(
                  decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              )),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10.0),
          width: width,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isDetectingFace.toString(),
                style: TextStyle(
                  fontSize: 24.0,
                  color: _isDetectingFace ? Colors.white : Colors.red,
                  backgroundColor:
                      _isDetectingFace ? Colors.green : Colors.red[100],
                ),
              ),
              SingleChildScrollView(
                scrollDirection:
                    Axis.vertical, // Esto permite el desplazamiento vertical
                child: Column(
                  children: [
                    Text(
                      _recognizedText,
                      style: const TextStyle(
                        fontSize: 24.0,
                        color: Colors.white,
                        backgroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10.0),
              _image != File('')
                  ? Image.file(
                      _image,
                      fit: BoxFit.fitHeight,
                      width: 200,
                      height: 200.0,
                    )
                  : Container(),
            ],
          ),
        )
      ]),
    );
  }
}
