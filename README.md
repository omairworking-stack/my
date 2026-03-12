POST /ERP/AuditAccounts/Analytics/Analyze
     ↓ responseType: 'blob'
Blob (binary .xlsx)
     ↓ blob.arrayBuffer()
ArrayBuffer
     ↓ XLSX.read(buffer, { type: 'array' })
WorkBook
     ↓ workbook.SheetNames  →  ['Financial Statements', 'Disclosures', ...]
     ↓ XLSX.utils.sheet_to_json(sheet, { header: 1 })
Array of rows per sheet
     ↓
Angular tabs (one per sheet name) + grid/table per tab

curl -X POST "https://your-host/ERP/AuditAccounts/Analytics/AnalyzeTrialBalance?analysisType=0" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"companyId":1,"financialYearID":5,"fromDate":"2024-04-01","toDate":"2025-03-31","reportType":"TB"}' \
  --output result.xlsx
