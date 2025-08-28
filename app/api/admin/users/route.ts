import { NextRequest, NextResponse } from "next/server"
import { createRouteHandlerClient } from "@supabase/auth-helpers-nextjs"
import { cookies } from "next/headers"
import jwt from "jsonwebtoken"

const JWT_SECRET = process.env.ADMIN_JWT_SECRET || "your-admin-secret-key"

// 验证管理员权限的中间件函数
async function verifyAdminAuth(request: NextRequest) {
  const token = request.cookies.get("admin_token")?.value

  if (!token) {
    return null
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET) as any
    return decoded
  } catch (error) {
    return null
  }
}

export async function GET(request: NextRequest) {
  try {
    // 验证管理员权限
    const admin = await verifyAdminAuth(request)
    if (!admin) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const cookieStore = cookies()
    const supabase = createRouteHandlerClient({ cookies: () => cookieStore })

    // 获取所有用户的基本信息
    let profiles: any[] = []

    // 尝试简单查询
    const { data: simpleProfiles, error: simpleError } = await supabase
      .from("profiles")
      .select("*")
      .order("created_at", { ascending: false })

    if (simpleError) {
      console.error("Error fetching profiles:", simpleError)
      return NextResponse.json(
        { error: "Failed to fetch user profiles" },
        { status: 500 }
      )
    }

    // 使用简单查询的结果，email设为username
    profiles =
      simpleProfiles?.map(p => ({
        ...p,
        email: p.username + "@example.com" // 临时解决方案
      })) || []

    // 获取所有用户的每日进度
    const { data: dailyProgress, error: progressError } = await supabase
      .from("user_daily_progress")
      .select("*")
      .order("session_date", { ascending: false })

    if (progressError) {
      console.error("Error fetching daily progress:", progressError)
    }

    // 获取所有emoji调查数据
    const { data: emojiSurveys, error: surveysError } = await supabase
      .from("emoji_surveys")
      .select("*")
      .order("created_at", { ascending: false })

    if (surveysError) {
      console.error("Error fetching emoji surveys:", surveysError)
    }

    // 获取所有聊天记录
    const { data: chats, error: chatsError } = await supabase
      .from("chats")
      .select("id, name, created_at, updated_at, user_id")
      .order("created_at", { ascending: false })

    if (chatsError) {
      console.error("Error fetching chats:", chatsError)
    }

    // 获取所有消息记录
    const { data: messages, error: messagesError } = await supabase
      .from("messages")
      .select("id, content, role, created_at, user_id, chat_id")
      .order("created_at", { ascending: false })
      .limit(1000) // 限制消息数量，避免数据过大

    if (messagesError) {
      console.error("Error fetching messages:", messagesError)
    }

    // 组织用户数据
    const usersData =
      profiles?.map(profile => {
        // 获取该用户的每日进度
        const userProgress =
          dailyProgress?.filter(
            progress => progress.user_id === profile.user_id
          ) || []

        // 获取该用户的emoji调查
        const userSurveys =
          emojiSurveys?.filter(survey => survey.user_id === profile.user_id) ||
          []

        // 获取该用户的聊天记录
        const userChats =
          chats?.filter(chat => chat.user_id === profile.user_id) || []

        // 获取该用户的消息记录
        const userMessages =
          messages?.filter(message => message.user_id === profile.user_id) || []

        // 计算统计数据
        const totalRequiredSurveys = userProgress.reduce(
          (sum, progress) => sum + progress.required_surveys_completed,
          0
        )
        const totalExtraSurveys = userProgress.reduce(
          (sum, progress) => sum + progress.extra_surveys_completed,
          0
        )
        const totalMessages = userMessages.length
        const totalChats = userChats.length

        // 计算活跃天数
        const uniqueDates = new Set(
          userProgress.map(progress => progress.session_date)
        )
        const activeDays = uniqueDates.size

        return {
          user_id: profile.user_id,
          email: profile.email,
          display_name: profile.display_name,
          username: profile.username,
          created_at: profile.created_at,
          has_onboarded: profile.has_onboarded,
          statistics: {
            total_required_surveys: totalRequiredSurveys,
            total_extra_surveys: totalExtraSurveys,
            total_messages: totalMessages,
            total_chats: totalChats,
            active_days: activeDays
          },
          daily_progress: userProgress,
          emoji_surveys: userSurveys,
          chats: userChats,
          messages: userMessages.slice(0, 50) // 只返回最近50条消息
        }
      }) || []

    return NextResponse.json({
      success: true,
      users: usersData,
      summary: {
        total_users: profiles?.length || 0,
        total_surveys: emojiSurveys?.length || 0,
        total_messages: messages?.length || 0,
        total_chats: chats?.length || 0
      }
    })
  } catch (error) {
    console.error("Admin users API error:", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}

// 获取特定用户的详细数据
export async function POST(request: NextRequest) {
  try {
    // 验证管理员权限
    const admin = await verifyAdminAuth(request)
    if (!admin) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 })
    }

    const { userId } = await request.json()

    if (!userId) {
      return NextResponse.json(
        { error: "User ID is required" },
        { status: 400 }
      )
    }

    const cookieStore = cookies()
    const supabase = createRouteHandlerClient({ cookies: () => cookieStore })

    // 获取用户详细信息
    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("*")
      .eq("user_id", userId)
      .single()

    if (profileError || !profile) {
      return NextResponse.json({ error: "User not found" }, { status: 404 })
    }

    // 获取用户的所有消息记录
    const { data: messages, error: messagesError } = await supabase
      .from("messages")
      .select(
        `
        id,
        content,
        role,
        created_at,
        chat_id,
        chats!inner(name)
      `
      )
      .eq("user_id", userId)
      .order("created_at", { ascending: true })

    if (messagesError) {
      console.error("Error fetching user messages:", messagesError)
    }

    // 获取用户的所有emoji调查
    const { data: surveys, error: surveysError } = await supabase
      .from("emoji_surveys")
      .select("*")
      .eq("user_id", userId)
      .order("created_at", { ascending: true })

    if (surveysError) {
      console.error("Error fetching user surveys:", surveysError)
    }

    // 获取用户的每日进度
    const { data: progress, error: progressError } = await supabase
      .from("user_daily_progress")
      .select("*")
      .eq("user_id", userId)
      .order("session_date", { ascending: true })

    if (progressError) {
      console.error("Error fetching user progress:", progressError)
    }

    return NextResponse.json({
      success: true,
      user: {
        ...profile,
        messages: messages || [],
        emoji_surveys: surveys || [],
        daily_progress: progress || []
      }
    })
  } catch (error) {
    console.error("Admin user detail API error:", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}
