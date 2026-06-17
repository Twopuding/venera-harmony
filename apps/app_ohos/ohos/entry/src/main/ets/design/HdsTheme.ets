import { hdsMaterial } from '@kit.UIDesignKit';

interface MaterialEffectConfig {
  materialType: hdsMaterial.MaterialType;
  materialLevel: hdsMaterial.MaterialLevel;
}

export class HdsTheme {
  static adaptiveMaterialEffect(): MaterialEffectConfig {
    let effect: MaterialEffectConfig = {
      materialType: hdsMaterial.MaterialType.ADAPTIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
    };
    return effect;
  }

  static resolveMaterialLevel(): hdsMaterial.MaterialLevel {
    let materialTypes: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes();
    if (materialTypes.indexOf(hdsMaterial.MaterialType.IMMERSIVE) < 0) {
      return hdsMaterial.MaterialLevel.SMOOTH;
    }
    return hdsMaterial.MaterialLevel.ADAPTIVE;
  }

  static cardBlurStyle(): BlurStyle {
    return BlurStyle.COMPONENT_ULTRA_THICK;
  }

  static thickBlurStyle(): BlurStyle {
    return BlurStyle.COMPONENT_THICK;
  }
}
