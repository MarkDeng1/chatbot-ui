import { FC } from "react"

interface FinishStepProps {
  displayName: string
}

export const FinishStep: FC<FinishStepProps> = ({ displayName }) => {
  return (
    <div className="max-h-[500px] space-y-6 overflow-y-auto">
      <div className="text-center">
        <h2 className="mb-2 text-2xl font-bold">
          Welcome to MentalShield Project
          {displayName.length > 0 ? `, ${displayName.split(" ")[0]}` : null}!
        </h2>
      </div>

      <div className="space-y-4 text-sm">
        <div className="rounded-lg bg-blue-50 p-4 dark:bg-blue-900/20">
          <h3 className="mb-2 font-semibold">
            Project Information & Consent Statement
          </h3>
          <p className="text-xs text-gray-600 dark:text-gray-400">
            Please read the following information carefully before proceeding.
          </p>
        </div>

        <div className="space-y-3">
          <div className="flex items-start space-x-2">
            <span className="mt-0.5 font-semibold text-blue-600 dark:text-blue-400">
              1.
            </span>
            <p>
              You have completed the pre-survey and been notified via email that
              you are eligible to participate in this project.
            </p>
          </div>

          <div className="flex items-start space-x-2">
            <span className="mt-0.5 font-semibold text-blue-600 dark:text-blue-400">
              2.
            </span>
            <p>
              This project will be conducted on this website for 7 days. You
              need to interact with your preferred character for at least 10
              minutes each day.
            </p>
          </div>

          <div className="flex items-start space-x-2">
            <span className="mt-0.5 font-semibold text-blue-600 dark:text-blue-400">
              3.
            </span>
            <p>
              Daily completion is marked by ensuring your daily progress bar
              shows you have completed 3 emoji surveys.
            </p>
          </div>

          <div className="flex items-start space-x-2">
            <span className="mt-0.5 font-semibold text-blue-600 dark:text-blue-400">
              4.
            </span>
            <p>
              If you complete 6 days of content, you will receive $30. Complete
              7 days plus additional surveys to receive $40.
            </p>
          </div>

          <div className="flex items-start space-x-2">
            <span className="mt-0.5 font-semibold text-blue-600 dark:text-blue-400">
              5.
            </span>
            <p>
              We will review chat content during the study. Highly repetitive or
              arbitrary content will result in email notification of data
              invalidation and immediate deletion of personal project
              information.
            </p>
          </div>

          <div className="flex items-start space-x-2">
            <span className="mt-0.5 font-semibold text-blue-600 dark:text-blue-400">
              6.
            </span>
            <p>
              You may withdraw from this project at any time by missing project
              tasks, and you will be automatically excluded.
            </p>
          </div>

          <div className="flex items-start space-x-2">
            <span className="mt-0.5 font-semibold text-blue-600 dark:text-blue-400">
              7.
            </span>
            <p>
              For any personal questions, please contact:{" "}
              <span className="font-mono text-blue-600 dark:text-blue-400">
                swinmentalshield@gmail.com
              </span>
            </p>
          </div>
        </div>

        <div className="rounded-lg border border-yellow-200 bg-yellow-50 p-4 dark:border-yellow-800 dark:bg-yellow-900/20">
          <p className="text-sm font-medium text-yellow-800 dark:text-yellow-200">
            By clicking Next, you confirm that you have read and understood the
            above information and provide your informed consent to participate
            in the MentalShield Project.
          </p>
        </div>
      </div>
    </div>
  )
}
