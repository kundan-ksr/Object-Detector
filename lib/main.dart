import 'package:animated_splash_screen/animated_splash_screen.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'package:tflite_v2/tflite_v2.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Object Detector',
      home: AnimatedSplashScreen(
        duration: 2000,
        splashIconSize: 245,
        splash: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(height: 100, child: Image.asset('assets/loading.gif')),
            SizedBox(height: 10),
            Text('Please Wait',
                style: TextStyle(color: Colors.white, fontSize: 24)),
          ],
        ),
        nextScreen: MainScreen(),
        splashTransition: SplashTransition.fadeTransition,
        pageTransitionType: PageTransitionType.rightToLeft,
        backgroundColor: Colors.black,
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool isWorking = false;
  late CameraController cameraController;
  CameraImage? imgCamera;
  String result = "";
  late double aspectRatio;

  @override
  void initState() {
    super.initState();
    initCamera();
    loadModel();
  }

  //Loading the model
  loadModel() async {
    await Tflite.loadModel(
      model: "assets/mobilenet_v1_1.0_224.tflite",
      labels: "assets/mobilenet_v1_1.0_224.txt",
    );
  }

  Future<void> initCamera() async {
    cameraController = CameraController(cameras[0], ResolutionPreset.high); // Updated to use higher resolution

    try {
      await cameraController.initialize();
      aspectRatio = cameraController.value.aspectRatio;
      setState(() {});

      cameraController.startImageStream((imageFromStream) {
        if (!isWorking) {
          setState(() {
            isWorking = true;
            imgCamera = imageFromStream;
            runModelOnStreamFrames();
          });
        }
      });
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  runModelOnStreamFrames() async {
    if (imgCamera != null) {
      // Ensure the image is resized to 224x224, which is expected by the MobileNet model
      var recognition = await Tflite.runModelOnFrame(
        bytesList: imgCamera?.planes.map((plane) {
          return plane.bytes;
        }).toList() ?? [],
        imageHeight: imgCamera?.height ?? 0,
        imageWidth: imgCamera?.width ?? 0,
        imageMean: 127.5,  // Normalization mean
        imageStd: 127.5,   // Normalization standard deviation
        rotation: 90,
        numResults: 3, // Increased number of results
        threshold: 0.4, // Lowered the threshold for detection
        asynch: true,
      );

      print("Raw Model Output: $recognition"); // Debug print statement

      String resultText = "";
      recognition?.forEach((response) {
        // Print response details for debugging
        print("Response: $response");

        resultText += "${response["label"]} ${(response["confidence"] as double).toStringAsFixed(2)}\n";
      });

      setState(() {
        result = resultText;
      });
      isWorking = false;
    }
  }

  @override
  void dispose() async {
    cameraController.dispose();
    super.dispose();
    await Tflite.close();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/image1.jpg"), // Background image of the app
            fit: BoxFit.cover,
          ),
        ),
        child: Column(
          children: [
            Stack(
              children: [
                Center(
                  child: Container(
                    margin: EdgeInsets.only(top: 40, left: 10, right: 10),
                    color: Colors.black,
                    height: 400,
                    width: 360,
                    child: Image.asset("assets/image2.jpg"), // Placeholder image
                  ),
                ),
                Center(
                  child: Container(
                    margin: EdgeInsets.only(top: 50),
                    height: 380,
                    width: 320,
                    child: imgCamera == null
                        ? Container(
                      height: 380,
                      width: 320,
                      child: Icon(Icons.photo_camera_front,
                          color: Colors.blueAccent, size: 40),
                    )
                        : AspectRatio(
                      aspectRatio: cameraController.value.aspectRatio,
                      child: CameraPreview(cameraController),
                    ),
                  ),
                ),
              ],
            ),
            Center(
              child: Container(
                margin: EdgeInsets.only(top: 55.0),
                child: SingleChildScrollView(
                  child: Text(
                    result,
                    style: TextStyle(
                      backgroundColor: Colors.black87,
                      fontSize: 30.0,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
