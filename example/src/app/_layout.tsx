import { DarkTheme, DefaultTheme, ThemeProvider } from 'expo-router';
import { useColorScheme } from 'react-native';

import { AnimatedSplashOverlay } from '@/components/animated-icon';
import AppTabs from '@/components/app-tabs';
import { Yolo } from 'react-native-yolo';
import { useEffect } from 'react';

export default function TabLayout() {
  const colorScheme = useColorScheme();
  useEffect(() => {
    Yolo.loadModelTest(require('@/assets/models/yolo.tflite'));
  }, []);
  return (
    <ThemeProvider value={colorScheme === 'dark' ? DarkTheme : DefaultTheme}>
      <AnimatedSplashOverlay />
      <AppTabs />
    </ThemeProvider>
  );
}
