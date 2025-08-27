import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription
} from "@/components/ui/dialog"
import { Button } from "@/components/ui/button"
import { useState, useEffect } from "react"

export function WelcomeDialog() {
  const [open, setOpen] = useState(false)
  const [selectedEmotion, setSelectedEmotion] = useState<number | null>(null)

  useEffect(() => {
    // 添加调试日志
    console.log("WelcomeDialog mounted")

    // 检查是否是首次登录
    const hasSeenWelcome = localStorage.getItem("hasSeenWelcome")
    console.log("hasSeenWelcome:", hasSeenWelcome)

    // 强制显示弹窗（用于测试）
    setOpen(true)

    // 设置标记
    localStorage.setItem("hasSeenWelcome", "true")
  }, [])

  const handleEmotionSelect = (value: number) => {
    setSelectedEmotion(value)
  }

  const handleConfirm = () => {
    if (selectedEmotion !== null) {
      // 这里可以添加提交情绪数据的逻辑
      console.log("Selected emotion:", selectedEmotion)

      // 选择并确认后关闭弹窗
      setOpen(false)
    }
  }

  return (
    <Dialog open={open} onOpenChange={() => {}}>
      <DialogContent
        className="sm:max-w-[500px]"
        onPointerDownOutside={e => e.preventDefault()}
      >
        <DialogHeader>
          <DialogTitle className="text-center text-xl font-bold">
            Welcome to Chat!
          </DialogTitle>
          <DialogDescription className="text-center">
            Emo Survey 1/3
          </DialogDescription>
          <p className="text-muted-foreground mt-2 text-center text-sm">
            Before start, you need to record your current state.
          </p>
        </DialogHeader>

        <div className="py-6">
          {/* 问题和emoji */}
          <div className="mb-6 text-center">
            <div className="mb-3 text-6xl">😊</div>
            <div className="text-lg font-medium">good about myself</div>
          </div>

          {/* 量表 */}
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <span className="text-sm text-gray-600">Very little</span>
              <span className="text-sm text-gray-600">Very much</span>
            </div>

            <div className="flex items-center justify-between px-4">
              {[1, 2, 3, 4, 5].map(value => (
                <button
                  key={value}
                  onClick={() => handleEmotionSelect(value)}
                  className={`size-8 rounded-full border-2 transition-all${
                    selectedEmotion === value
                      ? "scale-110 border-blue-500 bg-blue-500"
                      : "border-gray-300 hover:scale-105 hover:border-blue-300"
                  }`}
                >
                  {selectedEmotion === value && (
                    <div className="size-full scale-50 rounded-full bg-white"></div>
                  )}
                </button>
              ))}
            </div>

            <div className="flex justify-between px-4 text-xs text-gray-500">
              <span>1</span>
              <span>2</span>
              <span>3</span>
              <span>4</span>
              <span>5</span>
            </div>
          </div>

          {/* 确认按钮 */}
          <div className="mt-8 flex justify-center">
            <Button
              onClick={handleConfirm}
              disabled={selectedEmotion === null}
              className="px-8 py-2"
            >
              Confirm
            </Button>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  )
}
