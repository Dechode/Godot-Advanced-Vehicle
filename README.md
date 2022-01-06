# Godot-AdvancedVehicle
A more advanced car controller for the Godot game engine.

## Description

Custom rigidbody car controller with raycast suspension for the Godot game engine. This one is a bit more realistic than the built-in vehiclebody with wheelcolliders. Also easy to extend to be even more on the simulation side of vehicle controllers.

Features:
- 3 different tire models to choose from: simple pacejka model, brush tire model and one using godot curves. 
- Fuel consumption using BSFC
- Torque curve for the engine
- Simple engine sound
- Choose between preloaded limited slip diff, open diff and locked diff/solid axle
- Manual clutch
- Manual gearbox
- Different surfaces have different friction

This project would not have been possible without Wolfes written tutorial of his own car simulator physics. Also huge thank you to Bastiaan Olij for his vehicle demo. See the links in the Acknowledments section for more info.

## Controls

Keyboard:
- Arrow keys for throttle, brake and steering
- Space for handbrake
- A for upshifting and Z for downshifting
- c for clutch

Xbox controller:
- R2 for throttle and L2 for braking
- Left analog stick for steering
- A button for upshifting and X button for downshifting
- B button for handbrake

## Help

Make sure the physics FPS is set to atleast 120 or the physics start to get weird. In this project it is set to 240, which works fine for me.


## License

This project is licensed under the MIT License - see the LICENSE.md file for details. This project also contains models and textures owned by their authors. See links below for exact licenses.

Engine sound sample found in /sounds folder is made with enginesound, available from https://github.com/DasEtwas/enginesound. The sound sample itself is licensed under cc0.

## Acknowledgments

* [Kenney car kit](https://www.kenney.nl/assets/car-kit)
* [Bastiaan Olij - Vehicle demo](https://github.com/BastiaanOlij/vehicle-demo/)
* [Wolfe, written tutorial of his GDSim vehicle physics](https://www.gtplanet.net/forum/threads/gdsim-v0-4a-autocross-and-custom-setups.396400/)
