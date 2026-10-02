import { camera } from '@kit.CameraKit';
import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { abilityAccessCtrl, common, PermissionRequestResult } from '@kit.AbilityKit';
import { display } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

@Entry
@Component
struct Index {
  // ---------- 页面状态 ----------
  @State isPreviewing: boolean = false;                          // 预览是否已启动
  @State isMirrored: boolean = true;                             // 镜像显示（默认像照镜子）
  @State zoomRatio: number = 1;                                  // 当前变焦倍数
  @State zoomMin: number = 1;                                    // 支持的最小变焦
  @State zoomMax: number = 6;                                    // 支持的最大变焦
  @State frozen: boolean = false;                                // 是否定格
  @State frozenPixelMap: image.PixelMap | undefined = undefined; // 定格画面
  @State permissionDenied: boolean = false;
  @State rotQuarter: number = 0;   // 屏幕旋转档位（display.rotation：0/1/2/3）
  @State winW: number = 0;         // 窗口宽（vp）
  @State winH: number = 0;         // 窗口高（vp）
  @State zoomScale: number = 1;    // 图像数字变倍（1~5，双指捏合）
  @State panX: number = 0;         // 放大后查看位置（vp，屏幕坐标系）
  @State panY: number = 0;
  @State profileW: number = 0;     // 预览流规格宽（px，传感器方向）
  @State profileH: number = 0;     // 预览流规格高（px）

  // ---------- 相机对象（不驱动 UI，用普通私有变量）----------
  private context: common.UIAbilityContext | undefined = undefined;
  private surfaceId: string = '';
  private xComponentController: XComponentController = new XComponentController();
  private cameraManager: camera.CameraManager | undefined = undefined;
  private cameraInput: camera.CameraInput | undefined = undefined;
  private previewOutput: camera.PreviewOutput | undefined = undefined;
  private photoOutput: camera.PhotoOutput | undefined = undefined;
  private photoSession: camera.PhotoSession | undefined = undefined;
  private photoBuffer: ArrayBuffer | undefined = undefined;      // 最近一张照片数据

  aboutToAppear(): void {
    this.rotQuarter = display.getDefaultDisplaySync().rotation;
  }

  aboutToDisappear(): void {
    this.releaseCamera();
  }

  private pinchBase: number = 1;
  private panBaseX: number = 0;
  private panBaseY: number = 0;

  // ==================== 图像缩放 ====================

  private clampZoom(v: number): number {
    return Math.min(Math.max(v, 1), 5);
  }

  // 平移范围随倍率收紧，保证放大后画面始终覆盖全屏、不露出黑边
  private clampPan(): void {
    if (this.zoomScale <= 1.01) {
      this.panX = 0;
      this.panY = 0;
      return;
    }
    const f: number[] = this.coverFootprint();
    let maxX: number;
    let maxY: number;
    if (f[0] > 0) {
      maxX = (f[0] * this.zoomScale - this.winW) / 2;
      maxY = (f[1] * this.zoomScale - this.winH) / 2;
    } else {
      maxX = this.winW * (this.zoomScale - 1) / 2;
      maxY = this.winH * (this.zoomScale - 1) / 2;
    }
    this.panX = Math.min(Math.max(this.panX, -maxX), maxX);
    this.panY = Math.min(Math.max(this.panY, -maxY), maxY);
  }

  private resetZoom(): void {
    this.zoomScale = 1;
    this.panX = 0;
    this.panY = 0;
  }

  // ==================== 横竖屏适配 ====================

  private isLandscape(): boolean {
    return this.rotQuarter === 1 || this.rotQuarter === 3;
  }

  // 实测该机前置相机 HAL 的预览偏角：档位1 逆偏 90°、档位3 顺偏 90°，按档位反向回转把画面转正
  private compAngle(): number {
    switch (this.rotQuarter) {
      case 1:
        return 90;
      case 2:
        return 180;
      case 3:
        return 270;
      default:
        return 0;
    }
  }

  // 屏幕坐标系统一横向翻转：预览流出厂自带镜像、拍照流不带，两者极性相反
  private screenFlip(): ScaleOptions {
    const flip: boolean = this.frozen ? !this.isMirrored : this.isMirrored;
    return { x: flip ? 1 : -1, y: 1 };
  }

  // ==================== 画面比例 ====================

  // 该机相机流按竖屏方向各向异性拉伸填满 surface（实测），因此 surface 宽高比
  // 必须等于相机流比例，画面才不变形；再按 Cover 语义铺满屏幕：等比放大、窗口裁掉溢出。
  // 返回 [宽, 高]：内容铺满屏幕后的覆盖尺寸（vp，屏幕方向）
  private coverFootprint(): number[] {
    if (this.winW <= 0 || this.winH <= 0 || this.profileW <= 0 || this.profileH <= 0) {
      return [0, 0];
    }
    const longSide: number = Math.max(this.profileW, this.profileH);
    const shortSide: number = Math.min(this.profileW, this.profileH);
    const aspect: number = this.isLandscape() ? longSide / shortSide : shortSide / longSide;
    if (aspect > this.winW / this.winH) {
      return [aspect * this.winH, this.winH];
    }
    return [this.winW, this.winW / aspect];
  }

  // surface 尺寸：竖屏取覆盖尺寸本身；横屏宽高对调（旋转 90° 后 footprint 恰好铺满）
  private previewWidth(): Length {
    const f: number[] = this.coverFootprint();
    if (f[0] <= 0) {
      return '100%';
    }
    return this.isLandscape() ? f[1] : f[0];
  }

  private previewHeight(): Length {
    const f: number[] = this.coverFootprint();
    if (f[0] <= 0) {
      return '100%';
    }
    return this.isLandscape() ? f[0] : f[1];
  }

  // ==================== 相机逻辑 ====================

  private async requestCameraPermission(): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager();
      const result: PermissionRequestResult = await atManager.requestPermissionsFromUser(
        this.context!, ['ohos.permission.CAMERA']);
      return result.authResults.length > 0 && result.authResults[0] === 0;
    } catch (err) {
      return false;
    }
  }

  private async initCamera(): Promise<void> {
    if (this.isPreviewing) {
      return;
    }
    this.context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    if (!await this.requestCameraPermission()) {
      this.permissionDenied = true;
      return;
    }
    try {
      // 1. 找到前置摄像头
      this.cameraManager = camera.getCameraManager(this.context);
      const cameras: Array<camera.CameraDevice> = this.cameraManager.getSupportedCameras();
      const front: camera.CameraDevice | undefined = cameras.find(
        (c: camera.CameraDevice) => c.cameraPosition === camera.CameraPosition.CAMERA_POSITION_FRONT);
      if (!front) {
          this.getUIContext().getPromptAction().showToast({ message: '未找到前置摄像头' });
        return;
      }
      // 2. 创建输入并打开摄像头
      this.cameraInput = this.cameraManager.createCameraInput(front);
      await this.cameraInput.open();
      // 3. 获取输出能力，取第一个预览/拍照规格
      const capability: camera.CameraOutputCapability =
        this.cameraManager.getSupportedOutputCapability(front, camera.SceneMode.NORMAL_PHOTO);
      const previewProfile: camera.Profile = capability.previewProfiles[0];
      this.profileW = previewProfile.size.width;
      this.profileH = previewProfile.size.height;
      // 4. 预览绑定到 XComponent 的 surface，另建一路拍照输出
      this.previewOutput = this.cameraManager.createPreviewOutput(previewProfile, this.surfaceId);
      this.photoOutput = this.cameraManager.createPhotoOutput(capability.photoProfiles[0]);
      // 5. 创建 photo 会话并启动
      this.photoSession = this.cameraManager.createSession<camera.PhotoSession>(camera.SceneMode.NORMAL_PHOTO);
      this.photoSession.beginConfig();
      this.photoSession.addInput(this.cameraInput);
      this.photoSession.addOutput(this.previewOutput);
      this.photoSession.addOutput(this.photoOutput);
      await this.photoSession.commitConfig();
      await this.photoSession.start();
      this.isPreviewing = true;
      // 6. 读取支持的变焦范围
      const range: Array<number> = this.photoSession.getZoomRatioRange();
      if (range && range.length >= 2) {
        this.zoomMin = range[0];
        this.zoomMax = range[1];
        this.zoomRatio = range[0];
      }
      // 7. 监听拍照结果 → 生成定格画面
      this.photoOutput.on('photoAvailable', (err: BusinessError, photo: camera.Photo): void => {
        if (err || !photo) {
          return;
        }
        // API 26 起 Photo.main 是 image.Image，需取出 JPEG 分量再解码
        photo.main.getComponent(image.ComponentType.JPEG)
          .then((component: image.Component) => {
            const jpegBuffer: ArrayBuffer = component.byteBuffer.slice(0); // 拷贝出内部缓冲，用于解码和保存
            this.photoBuffer = jpegBuffer;
            return image.createImageSource(jpegBuffer).createPixelMap();
          })
          .then((pm: image.PixelMap) => {
            this.frozenPixelMap = pm;
            this.frozen = true;
          })
          .catch(() => {
            this.getUIContext().getPromptAction().showToast({ message: '照片处理失败' });
          })
          .finally(() => {
            photo.release().catch(() => {});
          });
      });
    } catch (err) {
      const e = err as BusinessError;
      this.getUIContext().getPromptAction().showToast({ message: `相机初始化失败：${e.code}` });
    }
  }

  private async releaseCamera(): Promise<void> {
    try {
      if (this.photoSession) {
        await this.photoSession.stop();
        await this.photoSession.release();
      }
      if (this.previewOutput) {
        await this.previewOutput.release();
      }
      if (this.cameraInput) {
        await this.cameraInput.close();
      }
    } catch (err) {
      // 忽略释放异常
    }
    this.isPreviewing = false;
  }

  private setZoom(value: number): void {
    const v = Math.min(Math.max(value, this.zoomMin), this.zoomMax);
    try {
      this.photoSession?.setZoomRatio(v);
    } catch (err) {
      // 超出设备支持范围时忽略
    }
  }

  private takePhoto(): void {
    if (!this.photoOutput) {
      return;
    }
    this.photoOutput.capture().catch(() => {
      this.getUIContext().getPromptAction().showToast({ message: '拍照失败，请重试' });
    });
  }

  // 保存到系统图库（点击 SaveButton 后已获得临时授权）
  private async savePhotoToGallery(): Promise<void> {
    const buffer = this.photoBuffer;
    if (!this.context || !buffer) {
      return;
    }
    try {
      const helper: photoAccessHelper.PhotoAccessHelper =
        photoAccessHelper.getPhotoAccessHelper(this.context);
      const uri: string = await helper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'jpg');
      const file = fileIo.openSync(uri, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE);
      fileIo.writeSync(file.fd, buffer);
      fileIo.closeSync(file);
      this.getUIContext().getPromptAction().showToast({ message: '已保存到图库' });
      this.frozen = false;
    } catch (err) {
      this.getUIContext().getPromptAction().showToast({ message: '保存失败' });
    }
  }

  // ==================== 界面 ====================

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Stack({ alignContent: Alignment.Center }) {
        // 平移层：放大后单指拖动查看（屏幕坐标系，方向不随旋转/镜像变化）
        Stack({ alignContent: Alignment.Center }) {
          // 屏幕翻转层：开关关闭时把预览横向翻转成"他人视角"（预览流本身已是镜像画面）
          Stack({ alignContent: Alignment.Center }) {
            // 旋转承载层：窗口旋转时把取景/定格画面整体转回正方向
            Stack() {
              // 取景画面（controller 改为在构造参数中绑定）
              XComponent({ id: 'mirrorSurface', type: XComponentType.SURFACE, controller: this.xComponentController })
                .onAppear(() => {
                  this.surfaceId = this.xComponentController.getXComponentSurfaceId();
                  this.initCamera();
                })
                .onDisAppear(() => {
                  this.releaseCamera();
                })
                .width(this.previewWidth())
                .height(this.previewHeight())

            // 定格画面（点击任意位置恢复取景）
            if (this.frozen && this.frozenPixelMap) {
              Image(this.frozenPixelMap)
                .width(this.previewWidth())
                .height(this.previewHeight())
                .objectFit(ImageFit.Cover)
                .onClick(() => {
                  this.frozen = false;
                })
            }
            }
            .width('100%')
            .height('100%')
            .rotate({ angle: this.compAngle() })
            .scale({ x: this.zoomScale, y: this.zoomScale })   // 图像数字变倍（等比，与旋转可交换）
          }
        .width('100%')
        .height('100%')
        .scale(this.screenFlip())   // 镜像翻转（屏幕坐标系；预览流与拍照流极性相反）
        }
        .width('100%')
        .height('100%')
        .translate({ x: this.panX, y: this.panY })   // 缩放后的查看位置

        // 缩放倍率指示
        if (this.zoomScale > 1.01) {
          Text(`${this.zoomScale.toFixed(1)}x`)
            .fontColor(Color.White)
            .fontSize(13)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor('#66000000')
            .borderRadius(12)
            .position({ x: '50%', y: 14 })
            .markAnchor({ x: '50%', y: 0 })
        }

        // 启动中 / 权限提示（不参与镜像翻转）
        if (!this.isPreviewing) {
          Stack({ alignContent: Alignment.Center }) {
            Text(this.permissionDenied ? '相机权限未授权\n请到设置中开启后重新进入' : '正在启动相机…')
              .fontColor(Color.White)
              .fontSize(15)
              .textAlign(TextAlign.Center)
              .lineHeight(24)
          }
          .width('100%')
          .height('100%')
        }
      }
      .width('100%')
      .height('100%')

      // 底部控制区
      Column({ space: 14 }) {
        if (this.frozen && this.frozenPixelMap) {
          // —— 定格状态：重拍 / 保存 ——
          Row({ space: 24 }) {
            Button('重拍')
              .height(44)
              .padding({ left: 24, right: 24 })
              .backgroundColor('#66000000')
              .fontColor(Color.White)
              .onClick(() => {
                this.frozen = false;
              })
            SaveButton({
              text: SaveDescription.SAVE_IMAGE,
              icon: SaveIconStyle.FULL_FILLED,
              buttonType: ButtonType.Capsule
            })
              .onClick(async (event: ClickEvent, result: SaveButtonOnClickResult) => {
                if (result === SaveButtonOnClickResult.SUCCESS) {
                  await this.savePhotoToGallery();
                }
              })
          }
        } else {
          // —— 取景状态：镜像开关 / 变焦 / 定格 ——
          Row({ space: 10 }) {
            Text('镜像').fontColor(Color.White).fontSize(15)
            Toggle({ type: ToggleType.Switch, isOn: this.isMirrored })
              .selectedColor('#B3FFFFFF')
              .onChange((isOn: boolean) => {
                this.isMirrored = isOn;
              })
          }
          .backgroundColor('#33000000')
          .borderRadius(20)
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })

          if (this.zoomMax > this.zoomMin) {
            Slider({ value: this.zoomRatio, min: this.zoomMin, max: this.zoomMax, step: 0.1 })
              .width('75%')
              .blockColor(Color.White)
              .selectedColor('#B3FFFFFF')
              .trackColor('#33FFFFFF')
              .onChange((value: number) => {
                this.zoomRatio = value;
                this.setZoom(value);
              })
          }

          // 快门（定格按钮）
          Circle({ width: 74, height: 74 })
            .fill('#E6FFFFFF')
            .stroke('#66000000')
            .strokeWidth(4)
            .onClick(() => {
              this.takePhoto();
            })
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 46 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Black)
    .onAreaChange((oldValue: Area, newValue: Area) => {
      this.winW = Number(newValue.width);
      this.winH = Number(newValue.height);
      this.rotQuarter = display.getDefaultDisplaySync().rotation;
      this.clampPan();
    })
    .gesture(
      GestureGroup(GestureMode.Exclusive,
        // 双指捏合：以捏合起点倍率为基准累乘
        PinchGesture({ fingers: 2 })
          .onActionStart((event: GestureEvent) => {
            this.pinchBase = this.zoomScale;
          })
          .onActionUpdate((event: GestureEvent) => {
            this.zoomScale = this.clampZoom(this.pinchBase * event.scale);
            this.clampPan();
          }),
        // 放大后单指拖动查看
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: 5 })
          .onActionStart((event: GestureEvent) => {
            this.panBaseX = this.panX;
            this.panBaseY = this.panY;
          })
          .onActionUpdate((event: GestureEvent) => {
            if (this.zoomScale <= 1.01) {
              return;
            }
            this.panX = this.panBaseX + event.offsetX;
            this.panY = this.panBaseY + event.offsetY;
            this.clampPan();
          }),
        // 双击复位
        TapGesture({ count: 2 })
          .onAction(() => {
            this.resetZoom();
          })
      )
    )
  }
}
