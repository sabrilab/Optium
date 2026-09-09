import {Config} from "@remotion/cli/config";

Config.setVideoImageFormat("jpeg");
Config.setOverwriteOutput(true);
// Le cerveau est rendu en WebGL : sans angle-egl, Chromium headless coupe
// le GPU et la scene tombe a quelques images par seconde.
Config.setChromiumOpenGlRenderer("angle-egl");
