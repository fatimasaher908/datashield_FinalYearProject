import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ImageViewerScreen extends StatefulWidget {
  final List<Uint8List> images;
  final int initialIndex;

  const ImageViewerScreen({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}


class _ImageViewerScreenState extends State<ImageViewerScreen> {

  late PageController pageController;
  late int currentIndex;


  @override
  void initState() {
    super.initState();

    currentIndex = widget.initialIndex;

    pageController = PageController(
      initialPage: currentIndex,
    );


    // Hide system bars like gallery apps
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
    );
  }



  @override
  void dispose() {

    pageController.dispose();


    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
    );


    super.dispose();
  }



  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Colors.black,


      body: Stack(

        children: [


          // IMAGE VIEWER

          PageView.builder(

            controller: pageController,

            itemCount: widget.images.length,


            onPageChanged: (index) {

              setState(() {

                currentIndex = index;

              });

            },


            itemBuilder: (context, index) {


              return InteractiveViewer(

                minScale: 1.0,

                maxScale: 5.0,

                panEnabled: true,

                scaleEnabled: true,


                child: Center(

                  child: Image.memory(

                    widget.images[index],

                    fit: BoxFit.contain,

                  ),

                ),

              );

            },

          ),




          // TOP BAR

          SafeArea(

            child: Padding(

              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 10,
              ),


              child: Row(

                mainAxisAlignment:
                MainAxisAlignment.spaceBetween,


                children: [


                  // BACK BUTTON

                  Container(

                    decoration: BoxDecoration(

                      color: Colors.black.withOpacity(0.45),

                      shape: BoxShape.circle,

                    ),


                    child: IconButton(

                      icon: const Icon(

                        Icons.arrow_back,

                        color: Colors.white,

                      ),


                      onPressed: () {

                        Navigator.pop(context);

                      },

                    ),

                  ),




                  // IMAGE COUNT

                  Container(

                    padding: const EdgeInsets.symmetric(

                      horizontal: 15,

                      vertical: 8,

                    ),


                    decoration: BoxDecoration(

                      color: Colors.black.withOpacity(0.45),

                      borderRadius:
                      BorderRadius.circular(20),

                    ),



                    child: Text(

                      "${currentIndex + 1} / ${widget.images.length}",


                      style: const TextStyle(

                        color: Colors.white,

                        fontSize: 15,

                        fontWeight: FontWeight.bold,

                      ),

                    ),

                  ),




                  // BALANCE SPACE

                  const SizedBox(

                    width: 50,

                  ),


                ],

              ),

            ),

          ),


        ],

      ),

    );

  }

}