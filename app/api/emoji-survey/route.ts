import { createClient } from "@supabase/supabase-js"
import { NextRequest, NextResponse } from "next/server"

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
)

export async function POST(request: NextRequest) {
  try {
    const {
      userId,
      emotionScore,
      questionText,
      surveyType = "daily_required",
      surveyOrder = 1
    } = await request.json()

    if (!userId || !emotionScore || !questionText) {
      return NextResponse.json(
        { error: "Missing required fields" },
        { status: 400 }
      )
    }

    // 验证UUID格式
    const uuidRegex =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    if (!uuidRegex.test(userId)) {
      return NextResponse.json(
        { error: "Invalid userId format - cannot submit survey" },
        { status: 400 }
      )
    }

    // 插入emoji survey记录
    const { data: surveyData, error: surveyError } = await supabase
      .from("emoji_surveys")
      .insert({
        user_id: userId,
        emotion_score: emotionScore,
        question_text: questionText,
        survey_type: surveyType,
        survey_order: surveyOrder,
        session_date: new Date().toISOString().split("T")[0] // YYYY-MM-DD format
      })
      .select()
      .single()

    if (surveyError) {
      console.error("Error inserting emoji survey:", surveyError)
      return NextResponse.json(
        { error: "Failed to save emoji survey" },
        { status: 500 }
      )
    }

    // 获取更新后的进度
    const { data: progressData, error: progressError } = await supabase
      .from("user_daily_progress")
      .select("*")
      .eq("user_id", userId)
      .eq("session_date", new Date().toISOString().split("T")[0])
      .single()

    if (progressError && progressError.code !== "PGRST116") {
      // PGRST116 = no rows returned
      console.error("Error fetching progress:", progressError)
    }

    return NextResponse.json({
      success: true,
      survey: surveyData,
      progress: progressData || {
        required_surveys_completed: 0,
        extra_surveys_completed: 0
      }
    })
  } catch (error) {
    console.error("Error in emoji survey API:", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const userId = searchParams.get("userId")
    const date =
      searchParams.get("date") || new Date().toISOString().split("T")[0]

    if (!userId) {
      return NextResponse.json(
        { error: "Missing userId parameter" },
        { status: 400 }
      )
    }

    // 验证UUID格式
    const uuidRegex =
      /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    if (!uuidRegex.test(userId)) {
      return NextResponse.json(
        {
          error: "Invalid userId format",
          progress: {
            required_surveys_completed: 0,
            extra_surveys_completed: 0
          },
          surveys: []
        },
        { status: 200 } // 改为200状态码，避免前端报错
      )
    }

    // 获取用户今日进度
    const { data: progressData, error: progressError } = await supabase
      .from("user_daily_progress")
      .select("*")
      .eq("user_id", userId)
      .eq("session_date", date)
      .single()

    if (progressError && progressError.code !== "PGRST116") {
      console.error("Error fetching progress:", progressError)
      return NextResponse.json(
        { error: "Failed to fetch progress" },
        { status: 500 }
      )
    }

    // 获取用户今日的surveys
    const { data: surveysData, error: surveysError } = await supabase
      .from("emoji_surveys")
      .select("*")
      .eq("user_id", userId)
      .eq("session_date", date)
      .order("created_at", { ascending: true })

    if (surveysError) {
      console.error("Error fetching surveys:", surveysError)
      return NextResponse.json(
        { error: "Failed to fetch surveys" },
        { status: 500 }
      )
    }

    return NextResponse.json({
      progress: progressData || {
        required_surveys_completed: 0,
        extra_surveys_completed: 0,
        session_date: date
      },
      surveys: surveysData || []
    })
  } catch (error) {
    console.error("Error in emoji survey GET API:", error)
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    )
  }
}
