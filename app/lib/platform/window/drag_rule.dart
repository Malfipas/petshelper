/// 鼠标按键位标记里「主键」那一位，与 Flutter 的 `kPrimaryMouseButton` 同值。
const int primaryButtonMask = 0x01;

/// 只有按住主键（左键）才起手拖动。
///
/// 右键、中键、两键同按都不算；左键与别的键一起按着仍算，手指没抬起来就该跟着走。
/// 界面层拿指针事件的 `buttons` 调它，判过才叫 `PetWindow.beginDrag()`。
bool canStartDrag(int buttons) => (buttons & primaryButtonMask) != 0;
