# AuditAccountsAnalytics API

**Endpoint:** `POST /api/AuditAccountsAnalytics/Analyze`  
**Content-Type:** `multipart/form-data`  
**Auth:** None required (`[AllowAnonymous]`)

---

## AnalysisType Enum Reference

| Int | Name | Excel Sheets Generated |
|-----|------|------------------------|
| `0` | `DraftAuditAccounts` | Financial Statements, Disclosures, Audit Schedules, Directors Report, Auditors Report, Company Information, PPE Schedule, Debtors Schedule, Income and Expenses Schedule, IFRS Disclosures |
| `1` | `Projections` | Projected Profit and Loss, Projected Cash Flow, Projected Balance Sheet, Loan Amortization, Ratio Analysis (EBITDA / Valuation / PE / EPS), Assumptions |
| `2` | `MultiYearAnalysis` | Multi Year Balance Sheet and PL, Current Year Balance Sheet and PL |

> Pass either the integer (`0`) or the string name (`DraftAuditAccounts`) — both are accepted.

---

## Request Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `AnalysisType` | `int` | Yes | See enum table above |
| `File` | `file` (multipart) | Yes | PDF containing financial data |

---

## cURL Examples

> Replace `https://your-api-host` with your actual base URL.  
> Response is a binary `.xlsx` file — use `--output` to save it.

### 0 — Draft Audit Accounts (10 sheets)
```bash
curl -X POST "https://your-api-host/api/AuditAccountsAnalytics/Analyze" \
  -F "AnalysisType=0" \
  -F "File=@/path/to/financials.pdf" \
  --output DraftAuditAccounts.xlsx
```

### 1 — Projections (6 sheets)
```bash
curl -X POST "https://your-api-host/api/AuditAccountsAnalytics/Analyze" \
  -F "AnalysisType=1" \
  -F "File=@/path/to/financials.pdf" \
  --output Projections.xlsx
```

### 2 — Multi-Year Analysis (2 sheets)
```bash
curl -X POST "https://your-api-host/api/AuditAccountsAnalytics/Analyze" \
  -F "AnalysisType=2" \
  -F "File=@/path/to/financials.pdf" \
  --output MultiYearAnalysis.xlsx
```

#### Windows (cmd) — use `^` for line continuation
```cmd
curl -X POST "https://your-api-host/api/AuditAccountsAnalytics/Analyze" ^
  -F "AnalysisType=0" ^
  -F "File=@C:\path\to\financials.pdf" ^
  --output DraftAuditAccounts.xlsx
```

---

## Response

| Scenario | HTTP Status | Body |
|----------|-------------|------|
| Success | `200 OK` | Binary `.xlsx` file download |
| No file sent | `400 Bad Request` | `{ "message": "A file is required for analysis." }` |
| Invalid analysis type | `400 Bad Request` | JSON error message |

### Success Response Headers
```
Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet
Content-Disposition: attachment; filename="DraftAuditAccounts_20260311.xlsx"
```

---

## Angular Integration

### 1. Model — `analytics.model.ts`

```typescript
export enum AnalysisType {
  DraftAuditAccounts = 0,
  Projections        = 1,
  MultiYearAnalysis  = 2,
}
```

### 2. Service — `analytics.service.ts`

```typescript
import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { AnalysisType } from '../models/analytics.model';

@Injectable({ providedIn: 'root' })
export class AnalyticsService {
  private readonly apiUrl = 'https://your-api-host/api/AuditAccountsAnalytics/Analyze';

  constructor(private http: HttpClient) {}

  analyze(analysisType: AnalysisType, file: File): Observable<Blob> {
    const form = new FormData();
    form.append('AnalysisType', analysisType.toString());
    form.append('File', file, file.name);

    return this.http.post(this.apiUrl, form, { responseType: 'blob' });
  }
}
```

### 3. PDF Validation Helper — `pdf-validator.ts`

```typescript
export interface PdfValidationResult {
  valid: boolean;
  error?: string;
}

const MAX_SIZE_MB = 20;

/** Synchronous checks: MIME type, extension, size */
export function validatePdf(file: File): PdfValidationResult {
  if (!file)
    return { valid: false, error: 'No file selected.' };
  if (file.type !== 'application/pdf')
    return { valid: false, error: 'Only PDF files are accepted.' };
  if (!file.name.toLowerCase().endsWith('.pdf'))
    return { valid: false, error: 'File must have a .pdf extension.' };
  const sizeMb = file.size / (1024 * 1024);
  if (sizeMb > MAX_SIZE_MB)
    return { valid: false, error: `File must be under ${MAX_SIZE_MB} MB (yours: ${sizeMb.toFixed(1)} MB).` };
  return { valid: true };
}

/** Async deep check: reads first 5 bytes and verifies the %PDF- magic header */
export function validatePdfMagicBytes(file: File): Promise<PdfValidationResult> {
  return new Promise((resolve) => {
    const reader = new FileReader();
    reader.onloadend = (e) => {
      const arr = new Uint8Array(e.target!.result as ArrayBuffer).subarray(0, 5);
      const header = String.fromCharCode(...arr);
      resolve(header === '%PDF-'
        ? { valid: true }
        : { valid: false, error: 'File is not a valid PDF.' });
    };
    reader.readAsArrayBuffer(file.slice(0, 5));
  });
}
```

### 4. Component — `analytics.component.ts`

```typescript
import { Component } from '@angular/core';
import { AnalysisType } from '../models/analytics.model';
import { AnalyticsService } from '../services/analytics.service';
import { validatePdf, validatePdfMagicBytes } from '../utils/pdf-validator';

@Component({
  selector: 'app-analytics',
  templateUrl: './analytics.component.html',
})
export class AnalyticsComponent {
  AnalysisType = AnalysisType;  // expose enum to template

  selectedType: AnalysisType = AnalysisType.DraftAuditAccounts;
  selectedFile: File | null = null;
  validationError = '';
  loading = false;
  errorMessage = '';

  constructor(private analyticsService: AnalyticsService) {}

  async onFileSelected(event: Event): Promise<void> {
    this.validationError = '';
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;

    // Step 1 — sync checks (type, extension, size)
    const basic = validatePdf(file);
    if (!basic.valid) {
      this.validationError = basic.error!;
      this.selectedFile = null;
      input.value = '';
      return;
    }

    // Step 2 — async check (%PDF- magic bytes)
    const deep = await validatePdfMagicBytes(file);
    if (!deep.valid) {
      this.validationError = deep.error!;
      this.selectedFile = null;
      input.value = '';
      return;
    }

    this.selectedFile = file;
  }

  analyze(): void {
    if (!this.selectedFile) {
      this.validationError = 'Please select a PDF file.';
      return;
    }

    this.loading = true;
    this.errorMessage = '';

    this.analyticsService.analyze(this.selectedType, this.selectedFile).subscribe({
      next: (blob) => {
        this.loading = false;
        const name = AnalysisType[this.selectedType];
        const date = new Date().toISOString().slice(0, 10).replace(/-/g, '');
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `${name}_${date}.xlsx`;
        a.click();
        URL.revokeObjectURL(url);
      },
      error: (err) => {
        this.loading = false;
        this.errorMessage = err?.error?.message ?? 'Analysis failed. Please try again.';
      },
    });
  }
}
```

### 5. Template — `analytics.component.html`

```html
<div class="analytics-form">
  <h2>Financial Analysis</h2>

  <!-- Analysis Type -->
  <div class="field">
    <label>Analysis Type</label>
    <select [(ngModel)]="selectedType">
      <option [value]="AnalysisType.DraftAuditAccounts">Draft Audit Accounts (10 sheets)</option>
      <option [value]="AnalysisType.Projections">Projections (6 sheets)</option>
      <option [value]="AnalysisType.MultiYearAnalysis">Multi-Year Analysis (2 sheets)</option>
    </select>
  </div>

  <!-- File Upload -->
  <div class="field">
    <label>Financial Data (PDF)</label>
    <input
      type="file"
      accept=".pdf,application/pdf"
      (change)="onFileSelected($event)"
    />
    <small>Max 20 MB · PDF only</small>
    <p class="error" *ngIf="validationError">{{ validationError }}</p>
  </div>

  <!-- Submit -->
  <button
    (click)="analyze()"
    [disabled]="loading || !selectedFile || !!validationError"
  >
    {{ loading ? 'Analysing — please wait…' : 'Analyse & Download Excel' }}
  </button>

  <p class="error" *ngIf="errorMessage">{{ errorMessage }}</p>
</div>
```

### 6. Module Setup — `app.module.ts`

```typescript
import { HttpClientModule } from '@angular/common/http';

@NgModule({
  imports: [
    HttpClientModule,
    FormsModule,  // required for [(ngModel)]
  ],
})
export class AppModule {}
```

---

## PDF Validation Rules

| Rule | Check |
|------|-------|
| File present | `file != null` |
| MIME type | `file.type === 'application/pdf'` |
| Extension | filename ends with `.pdf` |
| Size | ≤ 20 MB |
| Magic bytes | First 5 bytes equal `%PDF-` (async) |

---

## Notes

- Years and periods are **detected automatically** from the PDF — no need to pass them.
- Both **text-based and scanned PDFs** are supported (Claude reads the PDF natively).
- Processing can take up to **10 minutes** for large PDFs. Set a matching Angular timeout:

```typescript
import { timeout } from 'rxjs/operators';

this.http.post(this.apiUrl, form, { responseType: 'blob' })
  .pipe(timeout(600_000));  // 10 minutes
```
