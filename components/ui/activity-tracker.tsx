import { useEffect } from "react"

interface ActivityTrackerProps {
  onActivity: () => void
}

export function ActivityTracker({ onActivity }: ActivityTrackerProps) {
  useEffect(() => {
    // 监听键盘输入
    const handleKeyPress = () => {
      onActivity()
    }

    // 监听鼠标点击
    const handleClick = () => {
      onActivity()
    }

    // 监听鼠标移动（限制频率）
    let mouseMoveTimeout: NodeJS.Timeout | null = null
    const handleMouseMove = () => {
      if (mouseMoveTimeout) return
      mouseMoveTimeout = setTimeout(() => {
        onActivity()
        mouseMoveTimeout = null
      }, 1000) // 每秒最多触发一次
    }

    // 监听聊天输入框的输入事件
    const handleInputChange = () => {
      onActivity()
    }

    // 添加事件监听器
    document.addEventListener("keypress", handleKeyPress)
    document.addEventListener("keydown", handleKeyPress)
    document.addEventListener("click", handleClick)
    document.addEventListener("mousemove", handleMouseMove)
    document.addEventListener("input", handleInputChange)

    // 特别监听聊天输入框
    const chatInputs = document.querySelectorAll('textarea, input[type="text"]')
    chatInputs.forEach(input => {
      input.addEventListener("input", handleInputChange)
      input.addEventListener("focus", handleInputChange)
    })

    return () => {
      document.removeEventListener("keypress", handleKeyPress)
      document.removeEventListener("keydown", handleKeyPress)
      document.removeEventListener("click", handleClick)
      document.removeEventListener("mousemove", handleMouseMove)
      document.removeEventListener("input", handleInputChange)

      chatInputs.forEach(input => {
        input.removeEventListener("input", handleInputChange)
        input.removeEventListener("focus", handleInputChange)
      })

      if (mouseMoveTimeout) {
        clearTimeout(mouseMoveTimeout)
      }
    }
  }, [onActivity])

  return null // 这个组件不渲染任何内容
}
