import { Stack } from 'expo-router';

export default function ProjectsLayout() {
  return (
    <Stack
      screenOptions={{
        title: 'Projets',
        // Grand titre natif : il se replie au defilement et la barre prend son
        // fond translucide, comme dans Livres.
        headerLargeTitle: true,
        headerTransparent: true,
        headerBlurEffect: 'systemChromeMaterial',
        headerShadowVisible: false,
      }}
    />
  );
}
