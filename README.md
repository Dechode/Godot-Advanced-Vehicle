# Godot-AdvancedVehicle
A more advanced car controller for the Godot game engine.

## Description

Custom rigidbody car controller with raycast suspension for the Godot game engine. This one is a bit more realistic than the built-in vehiclebody with wheelcolliders. Also easy to extend to be even more on the simulation side of vehicle controllers.

Features:
- 3 different tire models to choose from: simple pacejka model, brush tire model and one using godot curves. 
- Fuel consumption using BSFC
- Torque curve for the engine
- Simple engine sound
- Choose between open diff, 1-way or 2-way simple Limited Slip Diff

This project would not have been possible without Wolfes written tutorial of his own car simulator physics. Also huge thank you to Bastiaan Olij for his vehicle demo. See the links in the Acknowledments section for more info.

## Help

Make sure the physics FPS is set to atleast 120 or the physics start to get weird. In this project it is set to 240, which works fine for me.


## License

This project is licensed under the MIT License - see the LICENSE.md file for details. This project also contains models and textures owned by their authors. See links below for exact licenses.

## Acknowledgments

* [Kenney car kit](https://www.kenney.nl/assets/car-kit)
* [Bastiaan Olij - Vehicle demo](https://github.com/BastiaanOlij/vehicle-demo/)
* [Wolfe, Written tutorial of his GDSim vehicle physics](https://www.gtplanet.net/forum/threads/gdsim-v0-4a-autocross-and-custom-setups.396400/)
