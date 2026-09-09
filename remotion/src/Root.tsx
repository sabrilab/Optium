import React from "react";
import {Composition} from "remotion";
import {Film} from "./Film";

/** Vertical 1080 x 1920, 60 s a 30 images par seconde. */
export const RemotionRoot: React.FC = () => (
  <>
    <Composition
      id="Film"
      component={Film}
      durationInFrames={60 * 30}
      fps={30}
      width={1080}
      height={1920}
    />
  </>
);
