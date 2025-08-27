import fs from 'fs'
import path from 'path'

export default function handler(req, res) {
  const filePath = path.join(process.cwd(), '../prompts_coser', 'prompts_test.jsonl')
  const fileContent = fs.readFileSync(filePath, 'utf-8')
  const prompts = fileContent.split('\n').map(line => JSON.parse(line))
  res.status(200).json(prompts)
}
