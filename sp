USE [dbERP]
GO
/****** Object:  StoredProcedure [dbo].[spGetTBBSPLData_NEW]    Script Date: 3/13/2026 12:01:16 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--spGetTBBSPLData_NEW 1,1, '2023-01-01','2023-12-31','Balance Sheet'

ALTER PROCEDURE [dbo].[spGetTBBSPLData_NEW]
@CompanyId INT = 1,
@CompanyFinancialYearId INT = 34,
@FromDate DATETIME = '03-01-2024',
@ToDate DATETIME = '09-10-2022',
@ReportType VARCHAR(20) = 'Balance Sheet'
AS
BEGIN

	IF (@ReportType = 'Balance Sheet')
	BEGIN

		SELECT
			@FromDate = StartDate
		FROM tblCompanyFinancialYearDetail
		WHERE CompanyFinancialYearDetailID = @CompanyFinancialYearId

	END

	Create TABLE #LedgerDetails  (
		LedgerId INT
	   ,LedgerName VARCHAR(100)
	   ,LedgerGroupId INT
	   ,OpeningBalanceCrDr VARCHAR(2)
	   ,OpeningBalanceAmount NUMERIC(18, 2)
	   ,Debit NUMERIC(18, 2)
	   ,Credit NUMERIC(18, 2)
	   ,NetTransaction NUMERIC(18, 2)
	   ,ClosingBalance NUMERIC(18, 2)
	   ,ClosingBalanceCrDr VARCHAR(2)
	   ,ReportTypeSequence INT
	   ,LedgerGroupSequence INT
	   ,ReportTypeId INT
	   ,PreviousYearBalance NUMERIC(18, 2)
	   ,PreviousYearBalanceCrDr VARCHAR(2)
	   ,LedgerOpeningBalance NUMERIC(18, 2)
	   ,LedgerOpeningBalanceCrDr VARCHAR(2)
	   ,CurrencyID INT
	   ,ClosingBalanceFc NUMERIC(18, 2)
	   ,ExRate NUMERIC(18, 2)
	)
	--select lfyob.ExRate,lfyob.FCAmount,lfyob.CurrencyID FROM tblLedgerFinanceYearOpeningBalance lfyob
	Create  TABLE #ReportData  (
		Id INT  INDEX IX1 CLUSTERED
		,IdStr VARCHAR(100) INDEX IX2 NONCLUSTERED(IdStr,ParentIdStr,ParentId,ExRate)
	   ,LedgerName VARCHAR(100)
	   ,ParentId INT
	   ,ParentIdStr VARCHAR(100)
	   ,OpeningBalanceCrDr VARCHAR(2)
	   ,OpeningBalanceAmount NUMERIC(18, 2)
	   ,Debit NUMERIC(18, 2)
	   ,Credit NUMERIC(18, 2)
	   ,NetTransaction NUMERIC(18, 2)
	   ,ClosingBalance NUMERIC(18, 2)
	   ,ClosingBalanceCrDr VARCHAR(2)
	   ,IsLedger BIT
	   ,ReportTypeSequence INT
	   ,LedgerGroupSequence INT
	   ,ReportTypeId INT
	   ,PreviousYearBalance NUMERIC(18, 2)
	   ,PreviousYearBalanceCrDr VARCHAR(2)
	   ,LedgerOpeningBalance NUMERIC(18, 2)
	   ,LedgerOpeningBalanceCrDr VARCHAR(2)
	   ,LedgerGroupId INT
	   ,CurrencyID INT
	   ,ClosingBalanceFc NUMERIC(18, 2)
	   ,ExRate NUMERIC(18, 2)
	   ,Ids varchar(max)
	)




	BEGIN -- Report Type
		DECLARE @ReportTypeTable TABLE ( ReportTypeId INT )
		INSERT INTO @ReportTypeTable
		SELECT * FROM dbo.fnReportTypes(@ReportType)
	END

	BEGIN -- All Ledger - opening balance as on from date
		DECLARE @LedgerOpeningBalance TABLE (
			LedgerId INT,
			LedgerGroupId INT,
			LedgerName VARCHAR(100),
			CurrencyId INT,
			OpeningBalance NUMERIC(18, 2),
			OpeningBalanceFC NUMERIC(18, 2),
			ExRate NUMERIC(18,2)
		)

		INSERT INTO @LedgerOpeningBalance (LedgerId,LedgerGroupId,LedgerName,CurrencyId ,OpeningBalance, OpeningBalanceFC,ExRate)
		SELECT *
		FROM [dbo].[fnLedgerOpeningBalance_OP] (@CompanyId, @FromDate, @ReportType, @CompanyFinancialYearId)
	END

	BEGIN

		DECLARE @FirstDay DATETIME

		SELECT
			@FirstDay = StartDate
		FROM tblCompanyFinancialYearDetail
		WHERE CompanyFinancialYearDetailID = @CompanyFinancialYearId

		-- Consider opening balance of all ledger only if the from date is the first day of financial year
		-- Else opening balance of trial balance report must match with closing balance of previous day
		-- of Balance sheet
		IF (@ReportType = 'Trial Balance' AND @FromDate > @FirstDay)
		BEGIN
			UPDATE OB
			SET 
				OB.OpeningBalance = 0
			   ,OB.OpeningBalanceFC = 0
			FROM 
				@LedgerOpeningBalance OB
				LEFT JOIN tblLedger L ON OB.LedgerId = L.LedgerId
				LEFT JOIN tblLedgerGroup LG ON L.LedgerGroupId = LG.LedgerGroupId
			WHERE LG.ReportTypeId NOT IN -- Balance Sheet
				(SELECT
						ReportTypeId
					FROM tblReportType
					WHERE ReportTypeName IN ('Assets', 'Liability'))
		END
	END

	BEGIN -- Transaction Ledgers - Debit/Credit Summary  - From-to date

		DECLARE @TotalDebitCredit TABLE (
			LedgerId INT
			,LedgerName Varchar(400)
			,LedgerGroupId INT
			,PreviousYearBalance NUMERIC(18, 2)
			,PreviousYearBalanceCrDr INT
			,CurrencyID INT
			,Amount NUMERIC(18, 2)
			,Amountp NUMERIC(18, 2)
			,ExRate NUMERIC(18, 2)
		   ,TotalDebit NUMERIC(18, 2)
		   ,TotalCredit NUMERIC(18, 2)
		   ,TotalDebitFc NUMERIC(18, 2)
		   ,TotalCreditFc NUMERIC(18, 2)
		)

		INSERT INTO @TotalDebitCredit
		SELECT
			VLD.LedgerId
			,l.LedgerName
			,l.LedgerGroupId 
			,l.PreviousYearBalance
			,l.PreviousYearBalanceCrDr 
			,l.CurrencyID
			,lfyob.Amount
			,lfyobp.Amount  
			,lfyob.ExRate
			,SUM(CASE
				WHEN VLD.CrDr = 1 THEN VLD.Amount
				ELSE 0
			END) AS TotalDebit
			,SUM(CASE
				WHEN VLD.CrDr = 0 THEN VLD.Amount
				ELSE 0
			END) AS TotalCredit
			,SUM(CASE
				WHEN VLD.CrDr = 1 AND
					VLD.CurrencyID = l.CurrencyID THEN VLD.ForeignCurrencyAmount
				ELSE 0
			END) AS TotalDebitFc
			,SUM(CASE
				WHEN VLD.CrDr = 0 AND
					VLD.CurrencyID = l.CurrencyID THEN VLD.ForeignCurrencyAmount
				ELSE 0
			END) AS TotalCreditFc
		FROM 
			tblVoucherLedgerDetail VLD
			LEFT JOIN vwVoucher V ON VLD.VoucherID = V.VoucherID
			LEFT JOIN tblLedger l ON VLD.LedgerID = l.LedgerID
			LEFT JOIN tblLedgerFinanceYearOpeningBalance lfyob ON lfyob.LedgerId = VLD.LedgerId
				AND lfyob.FinancialYearID = @CompanyFinancialYearId

				LEFT JOIN tblLedgerFinanceYearOpeningBalance lfyobp
				ON L.LedgerId = lfyobp.LedgerId
					AND lfyobp.FinancialYearID = (SELECT
							MAX(t.FinancialYearID)
						FROM tblLedgerFinanceYearOpeningBalance t
						WHERE t.LedgerId = lfyobp.LedgerId
						AND t.FinancialYearID < @CompanyFinancialYearId)
		WHERE
			V.IsAuthorized = 1
			AND V.CompanyID = @CompanyId
			AND V.VoucherDate >= @FromDate
			AND V.VoucherDate <= @ToDate
			AND ISNULL(VLD.LedgerId, 0) > 0
		GROUP BY 
			VLD.LedgerId
				
	,	l.LedgerName
			,l.LedgerGroupId 
		,l.PreviousYearBalance
			,l.PreviousYearBalanceCrDr 
	,l.CurrencyID
	,lfyob.Amount
	,lfyobp.Amount 
	,lfyob.ExRate
	END



	BEGIN -- Opening Stock

		DECLARE @OpeningStockBalance NUMERIC(18, 2)
			   ,@ClosingStockBalance NUMERIC(18, 2)
		SELECT
			@OpeningStockBalance = [dbo].fnGetOpeningStockBalance(@CompanyId, @FromDate, @ReportType, @CompanyFinancialYearId)

		-- Calculate closing stock as on To Date
		SELECT
			@ClosingStockBalance = [dbo].fnGetOpeningStockBalance(@CompanyId, DATEADD(DAY, 1, @ToDate), @ReportType, @CompanyFinancialYearId)
--@ClosingStockBalance = [dbo].fnGetOpeningStockBalance(@CompanyId,   @ToDate, @ReportType, @CompanyFinancialYearId)
		IF (@ReportType = 'Profit & Loss')
		BEGIN
			SET @ClosingStockBalance = (-1 * @ClosingStockBalance)
		END

		DECLARE @OpeningStockGroup INT
			   ,@OpeningStockReportType INT

		DECLARE @InventoryStockGroup INT
		SELECT 
			@InventoryStockGroup = LedgerGroupID 
		FROM tblLedgerGroup WHERE LedgerGroupName = 'Opening Stock' AND CompanyID = @CompanyId

		IF (@ReportType = 'Trial Balance'
			OR @ReportType = 'Profit & Loss')
		BEGIN
			SELECT
				@OpeningStockGroup = LedgerGroupId
			   ,@OpeningStockReportType = ReportTypeId
			FROM tblLedgerGroup
			WHERE LedgerGroupName = 'Purchase Accounts'
			AND CompanyID = @CompanyId
		END

		IF (@ReportType = 'Balance Sheet')
		BEGIN
			SELECT
				@OpeningStockGroup = LedgerGroupId
			   ,@OpeningStockReportType = ReportTypeId
			FROM tblLedgerGroup
			WHERE LedgerGroupName = 'Current Assets'
			AND CompanyID = @CompanyId
		END

	END

	

	BEGIN -- Transaction Ledgers - Report Details
	

		INSERT INTO #LedgerDetails
			SELECT
				T.LedgerId
			   ,T.LedgerName
			   ,T.LedgerGroupId
			   ,CASE
					WHEN OB.OpeningBalance > 0 THEN 'Dr'
					WHEN OB.OpeningBalance < 0 THEN 'Cr'
					ELSE ''
				END AS OpeningBalanceCrDr
			   ,ISNULL(OB.OpeningBalance, 0) AS OpeningBalance
			   ,ISNULL(T.TotalDebit, 0)
			   ,ISNULL(T.TotalCredit, 0)
			   ,(T.TotalDebit - T.TotalCredit) AS NetTransaction
			   ,CASE
					WHEN @ReportType = 'Profit & Loss' THEN T.TotalDebit - T.TotalCredit

					ELSE ISNULL(OB.OpeningBalance, 0) + T.TotalDebit - T.TotalCredit
				END AS ClosingBalance
			   ,CASE
					WHEN
						(CASE
							WHEN @ReportType = 'Profit & Loss' THEN T.TotalDebit - T.TotalCredit

							ELSE ISNULL(OB.OpeningBalance, 0) + T.TotalDebit - T.TotalCredit
						END)
						>= 0 THEN 'Dr'
					ELSE 'Cr'
				END AS ClosingBalanceCrDr
			   ,RT.ReportTypeSequence
			   ,LG.LedgerGroupSequence
			   ,RT.ReportTypeId
			   ,CASE
					WHEN T.PreviousYearBalanceCrDr = 1 THEN ISNULL(T.PreviousYearBalance, 0)
					ELSE -1 * ISNULL(T.PreviousYearBalance, 0)
				END AS PreviousYearBalance
			   ,CASE
					WHEN T.PreviousYearBalanceCrDr = 0 THEN 'Cr'
					WHEN T.PreviousYearBalanceCrDr = 1 THEN 'Dr'
					ELSE ''
				END AS PreviousYearBalanceCrDr
			   ,ISNULL(T.Amount, 0) + ISNULL(T.Amountp, 0) AS LedgerOpeningBalance
			   ,CASE
					WHEN ISNULL(T.Amount, 0) > 0 THEN 'Dr'
					WHEN ISNULL(T.Amount, 0) < 0 THEN 'Cr'
					ELSE ''
				END AS LedgerOpeningBalanceCrDr
			   ,T.CurrencyID
			   ,CASE
					WHEN @ReportType = 'Profit & Loss' THEN T.TotalDebitFc - T.TotalCreditFc
					ELSE ISNULL(OB.OpeningBalanceFC ,0)+ ISNULL(T.TotalDebitFc,0) - ISNULL(T.TotalCreditFc,0)
				END AS ClosingBalanceFc
				-- ,lfyob.FCAmount  
			   ,T.ExRate
			FROM 
			@TotalDebitCredit T
			LEFT JOIN @LedgerOpeningBalance OB ON T.LedgerId = OB.LedgerId
			LEFT JOIN tblLedgerGroup LG ON T.LedgerGroupId = LG.LedgerGroupId
			LEFT JOIN tblReportType RT ON LG.ReportTypeId = RT.ReportTypeId
	END


	BEGIN -- Remaining Ledgers - Report Details (TB / BS Only)
		--IF (@ReportType = 'Trial Balance' OR @ReportType = 'Balance Sheet')
		--BEGIN
		INSERT INTO #LedgerDetails
			SELECT
				OB.LedgerId
			   ,OB.LedgerName
			   ,OB.LedgerGroupId
			   ,CASE
					WHEN OB.OpeningBalance > 0 THEN 'Dr'
					WHEN OB.OpeningBalance < 0 THEN 'Cr'
					ELSE ''
				END AS OpeningBalanceCrDr
			   ,ISNULL(OB.OpeningBalance, 0) AS OpeningBalance
			   ,0 AS TotalDebit
			   ,0 AS TotalCredit
			   ,0 AS NetTransaction
			   ,CASE
					WHEN @ReportType = 'Profit & Loss' THEN 0
					ELSE OB.OpeningBalance
				END AS ClosingBalance
			   ,CASE
					WHEN
						(CASE
							WHEN @ReportType = 'Profit & Loss' THEN 0
							ELSE OB.OpeningBalance
						END)
						>= 0 THEN 'Dr'
					ELSE 'Cr'
				END AS ClosingBalanceCrDr
			   ,RT.ReportTypeSequence
			   ,LG.LedgerGroupSequence
			   ,RT.ReportTypeId
			   ,CASE
					WHEN T.PreviousYearBalanceCrDr = 1 THEN ISNULL(T.PreviousYearBalance, 0)
					ELSE -1 * ISNULL(T.PreviousYearBalance, 0)
				END AS PreviousYearBalance
			   ,CASE
					WHEN T.PreviousYearBalanceCrDr = 0 THEN 'Cr'
					WHEN T.PreviousYearBalanceCrDr = 1 THEN 'Dr'
					ELSE ''
				END AS PreviousYearBalanceCrDr
			   ,ISNULL(T.Amount, 0) + ISNULL(T.Amountp, 0) AS LedgerOpeningBalance
			   ,CASE
					WHEN ISNULL(T.Amount, 0) > 0 THEN 'Dr'
					WHEN ISNULL(T.Amount, 0) < 0 THEN 'Cr'
					ELSE ''
				END
				AS LedgerOpeningBalanceCrDr
			   ,ISNULL(T.CurrencyID,OB.CurrencyId)
			   ,CASE
					WHEN @ReportType = 'Profit & Loss' THEN 0
					ELSE ISNULL(OB.OpeningBalanceFC,0)
				END AS ClosingBalanceFc
			   ,CASE WHEN T.ExRate IS NULL OR T.ExRate = 0 THEN OB.ExRate ELSE T.ExRate END
			FROM 
				@LedgerOpeningBalance OB
			LEFT JOIN 	@TotalDebitCredit T ON OB.LedgerId = T.LedgerId
			
			LEFT JOIN tblLedgerGroup LG ON OB.LedgerGroupId = LG.LedgerGroupId
			LEFT JOIN tblReportType RT ON LG.ReportTypeId = RT.ReportTypeId
			WHERE OB.LedgerId NOT IN (SELECT LedgerId FROM @TotalDebitCredit)
	-- END
	END

	BEGIN -- REPORT: Insert ledger groups with N level
		INSERT INTO #ReportData
			SELECT
				LG.LedgerGroupId AS Id
				,'G' + cast(LG.LedgerGroupId as varchar(100)) AS IdStr
			   ,LG.LedgerGroupName AS LedgerName
			   ,ISNULL(LG.ParentLedgerGroupID, 0) AS ParentId
			   ,'G' + Cast(ISNULL(LG.ParentLedgerGroupID, 0) as varchar(100)) As ParentIdStr
			   ,'' AS OpeningBalanceCrDr
			   ,0 AS OpeningBalanceAmount
			   ,0 AS Debit
			   ,0 AS Credit
			   ,0 AS NetTransaction
			   ,0 AS ClosingBalance
			   ,'' AS ClosingBalanceCrDr
			   ,CAST(0 AS BIT) AS IsLedger
			   ,RT.ReportTypeSequence
			   ,LG.LedgerGroupSequence
			   ,RT.ReportTypeId
			   ,0 AS PreviousYearBalance
			   ,'' AS PreviousYearBalanceCrDr
			   ,0 AS LedgerOpeningBalance
			   ,'' AS LedgerOpeningBalanceCrDr
			   ,LG.LedgerGroupId
			   ,0 AS CurrencyID
			   ,0 AS ClosingBalanceFc
			   ,0 AS ExRate
			   ,''
			FROM 
				tblLedgerGroup LG
				LEFT JOIN tblReportType RT ON LG.ReportTypeId = RT.ReportTypeId
			WHERE 
				LG.CompanyID = @CompanyId
	END

	

	BEGIN -- REPORT: Insert Ledger (Transaction + Opening) details
		INSERT INTO #ReportData
			SELECT
				ISNULL(LD.LedgerId, 0) AS Id
				,'L' + cast(LD.LedgerId as varchar(100)) as IdStr
			   ,LD.LedgerName
			   ,ISNULL(LD.LedgerGroupId, 0) AS LedgerGroupId
			   ,'G' + Cast(ISNULL(LD.LedgerGroupId, 0) as varchar(100)) As ParentIdStr
			   ,LD.OpeningBalanceCrDr
			   ,ISNULL(LD.OpeningBalanceAmount, 0) AS OpeningBalanceAmount
			   ,LD.Debit
			   ,LD.Credit
			   ,LD.NetTransaction AS NetTransaction
			   ,LD.ClosingBalance AS ClosingBalance
			   ,LD.ClosingBalanceCrDr
			   ,CAST(1 AS BIT) AS IsLedger
			   ,ISNULL(LD.ReportTypeSequence, 0) AS ReportTypeSequence
			   ,ISNULL(LD.LedgerGroupSequence, 0) AS LedgerGroupSequence
			   ,ISNULL(LD.ReportTypeID, 0) AS ReportTypeID
			   ,LD.PreviousYearBalance
			   ,LD.PreviousYearBalanceCrDr
			   ,LD.LedgerOpeningBalance
			   ,LD.LedgerOpeningBalanceCrDr
			   ,LD.LedgerGroupId

			   ,LD.CurrencyID
			   ,LD.ClosingBalanceFc
			   ,LD.ExRate
			   ,''
			--  , LD.ExRate  AS ExRate
			--,ISNULL(LD.CurrencyID,0)AS CurrencyID
			--, LD.FCAmount AS FCAmount

			FROM #LedgerDetails LD


				
	END

	BEGIN -- Current Year

		UPDATE #ReportData
		SET 
			ClosingBalance = 0
		   ,ClosingBalanceCrDr = ''
		   ,ClosingBalanceFc = 0
		WHERE 
			ReportTypeId NOT IN (SELECT ReportTypeId FROM @ReportTypeTable)

	END

	BEGIN -- REPORT: Opening Stock
		-- Opening stock
		INSERT INTO #ReportData
			SELECT
				Id
				,'L' + cast(Id as varchar(100)) as IdStr
			   ,LedgerName
			   ,ISNULL(ParentId, 0) AS ParentId
			   ,'G' + Cast(ISNULL(ParentId, 0) as varchar(100)) As ParentIdStr
			   ,OpeningBalanceCrDr
			   ,OpeningBalanceAmount
			   ,0 AS Debit
			   ,0 AS Credit
			   ,0 AS NetTransaction
			   ,CASE
					WHEN @ReportType = 'Profit & Loss' THEN 0
					ELSE OpeningBalanceAmount
				END AS ClosingBalance
			   ,CASE
					WHEN
						(CASE
							WHEN @ReportType = 'Profit & Loss' THEN 0
							ELSE OpeningBalanceAmount
						END)
						>= 0 THEN 'Dr'
					ELSE 'Cr'
				END AS ClosingBalanceCrDr
			   ,IsLedger
			   ,ReportTypeSequence
			   ,LedgerGroupSequence
			   ,ReportTypeId
			   ,PreviousYearBalance
			   ,PreviousYearBalanceCrDr
			   ,LedgerOpeningBalance
			   ,LedgerOpeningBalanceCrDr
			   ,LedgerGroupId
			   ,0 AS CurrencyID
			   ,CASE
					WHEN @ReportType = 'Profit & Loss' THEN 0
					ELSE OpeningBalanceAmountFc
				END AS ClosingBalanceFc
			   ,0 AS ExRate
			   ,''
			FROM (SELECT

					-1 AS Id
				   ,'Inventory Stock' AS LedgerName
				   -- ,ISNULL(@OpeningStockGroup, 0) AS ParentId
				   , ISNULL(@InventoryStockGroup, 0) AS ParentId
				   ,CASE
						WHEN @ReportType <> 'Balance Sheet' THEN CASE
								WHEN @OpeningStockBalance > 0 THEN 'Dr'
								WHEN @OpeningStockBalance < 0 THEN 'Cr'
								ELSE ''
							END
						ELSE ''
					END AS OpeningBalanceCrDr
				   ,CASE
						WHEN @ReportType <> 'Balance Sheet' THEN ISNULL(@OpeningStockBalance, 0)
						ELSE 0
					END AS OpeningBalanceAmount
				   ,CASE
						WHEN @ReportType <> 'Balance Sheet' THEN ISNULL(@OpeningStockBalance, 0)
						ELSE 0
					END AS OpeningBalanceAmountFc
				   ,0 AS Debit
				   ,0 AS Credit
				   ,0 AS NetTransaction
				   ,CAST(0 AS BIT) AS IsLedger
				   ,-1 AS ReportTypeSequence
				   ,-1 AS LedgerGroupSequence
				   ,@OpeningStockReportType AS ReportTypeID
				   ,0 AS PreviousYearBalance
				   ,'' AS PreviousYearBalanceCrDr
				   ,

					-- For balance sheet, Opening Stock under previous year balance column
					CASE
						WHEN @ReportType = 'Balance Sheet' THEN ISNULL(@OpeningStockBalance, 0)
						ELSE 0
					END AS LedgerOpeningBalance
				   ,CASE
						WHEN @ReportType = 'Balance Sheet' THEN CASE
								WHEN @OpeningStockBalance > 0 THEN 'Dr'
								WHEN @OpeningStockBalance < 0 THEN 'Cr'
								ELSE ''
							END
						ELSE ''
					END AS LedgerOpeningBalanceCrDr
				   ,0 AS LedgerGroupID


				   ,0 AS CurrencyID
				   ,0 AS FCAmount
				   ,0 AS ExRate) AS X





		-- Insert closing stock for P&L and BS
		IF (@ReportType = 'Profit & Loss'
			OR @ReportType = 'Balance Sheet')
		BEGIN
			
			IF (@ReportType = 'Profit & Loss')
			BEGIN
				SELECT
					@OpeningStockGroup = LedgerGroupId
				FROM tblLedgerGroup
				WHERE LedgerGroupName = 'Cost Of Sales'
				AND CompanyID = @CompanyId
			END

			INSERT INTO #ReportData
				SELECT
					Id
					,'L' + cast(Id as varchar(100)) as IdStr
				   ,LedgerName
				   ,ISNULL(ParentId, 0) AS ParentId
				   ,'G' + Cast(ISNULL(ParentId, 0) as varchar(100)) As ParentIdStr
				   ,OpeningBalanceCrDr
				   ,OpeningBalanceAmount
				   ,0 AS Debit
				   ,0 AS Credit
				   ,0 AS NetTransaction
				   ,OpeningBalanceAmount AS ClosingBalance
				   ,CASE
						WHEN OpeningBalanceAmount >= 0 THEN 'Dr'
						ELSE 'Cr'
					END AS ClosingBalanceCrDr
				   ,IsLedger
				   ,ReportTypeSequence
				   ,LedgerGroupSequence
				   ,ReportTypeId
				   ,PreviousYearBalance
				   ,PreviousYearBalanceCrDr
				   ,LedgerOpeningBalance
				   ,LedgerOpeningBalanceCrDr
				   ,LedgerGroupId
				   ,0 AS CurrencyID
				   ,OpeningBalanceAmountFc AS ClosingBalanceFc
				   ,0 AS ExRate
				   ,''
				FROM (SELECT
						-5 AS Id
					   ,'Closing Stock Consumables' AS LedgerName
					   ,ISNULL(@OpeningStockGroup, 0) AS ParentId
					   ,CASE
							WHEN @ClosingStockBalance > 0 THEN 'Dr'
							WHEN @ClosingStockBalance < 0 THEN 'Cr'
							ELSE ''
						END
						AS OpeningBalanceCrDr
					   ,ISNULL(@ClosingStockBalance, 0) AS OpeningBalanceAmount
					   ,0 AS Debit
					   ,0 AS Credit
					   ,0 AS NetTransaction
					   ,CAST(0 AS BIT) AS IsLedger
					   ,-1 AS ReportTypeSequence
					   ,1000 AS LedgerGroupSequence
					   ,@OpeningStockReportType AS ReportTypeID
					   ,0 AS PreviousYearBalance
					   ,'' AS PreviousYearBalanceCrDr
					   ,0 AS LedgerOpeningBalance
					   ,'' AS LedgerOpeningBalanceCrDr
					   ,0 AS LedgerGroupID
					   ,0 AS CurrencyID
					   ,ISNULL(@ClosingStockBalance, 0) AS OpeningBalanceAmountFc
					   ,0 AS ExRate) AS X
		END
	END


	BEGIN -- Consider Opening Stock balance in Profit & Loss Report
		IF (@ReportType = 'Profit & Loss')
		BEGIN
			UPDATE #ReportData
			SET ClosingBalance = OpeningBalanceAmount + Debit - Credit
			   ,ClosingBalanceCrDr =
				CASE
					WHEN (OpeningBalanceAmount + Debit - Credit) >= 0 THEN 'Dr'
					ELSE 'Cr'
				END
			   ,ClosingBalanceFc = 0
			WHERE LedgerName IN

			('Inventory Stock', 'Opening Stock', 'Opening Balance - Finished Goods',
			'Opening Balance - Raw Materials', 'Opening Balance - Work-in-progress')
		END
	END

	BEGIN -- REPORT: Gross / Net Profit / Loss

		DECLARE @GrossProfit NUMERIC(18, 2)
			   ,@NetProfit NUMERIC(18, 2)
			   ,@PreviousYearGrossProfit NUMERIC(18, 2) = 0
			   ,@PreviousYearNetProfit NUMERIC(18, 2) = 0
			   ,@PreviousYearClosingBalance NUMERIC(18, 2) = 0
			   ,@ProfitGroup INT = NULL

		DECLARE @PLFromDate DATETIME
			   ,@PLTodate DATETIME

		IF (@ReportType = 'Trial Balance')
		BEGIN
			SELECT
				@PLFromDate = StartDate
			FROM tblCompanyFinancialYearDetail
			WHERE CompanyFinancialYearDetailID = @CompanyFinancialYearId

			SET @PLTodate = DATEADD(DAY, -1, @FromDate)

			SELECT
				@GrossProfit = GrossProfit
			   ,@NetProfit = NetProfit
			FROM [dbo].[fnProfitDetails](@CompanyId, @PLFromDate, @PLTodate, 'Balance Sheet',
			CASE
				WHEN @FromDate = @FirstDay THEN 1
				ELSE 0
			END, @CompanyFinancialYearId)
		END

		DECLARE @RevenueClosingBalance NUMERIC(18, 2)
			   ,@ProductionExpenseClosingBalance NUMERIC(18, 2)
			   ,@OtherRevenueClosingBalance NUMERIC(18, 2)
			   ,@OtherExpenditureClosingBalance NUMERIC(18, 2)

		IF (@ReportType = 'Profit & Loss')
		BEGIN
			-- Current Year
			SELECT
				@RevenueClosingBalance = SUM(OpeningBalanceAmount) + (SUM(Debit) - SUM(Credit))
			FROM #ReportData
			WHERE ReportTypeId IN (SELECT
					ReportTypeId
				FROM tblReportType
				WHERE ReportTypeName IN ('Revenue'))

			SELECT
				@OtherRevenueClosingBalance = SUM(OpeningBalanceAmount) + (SUM(Debit) - SUM(Credit))
			FROM #ReportData
			WHERE ReportTypeId IN (SELECT
					ReportTypeId
				FROM tblReportType
				WHERE ReportTypeName IN ('Other Revenue'))

			SELECT
				@OtherExpenditureClosingBalance = SUM(OpeningBalanceAmount) + (SUM(Debit) - SUM(Credit))
			FROM #ReportData
			WHERE ReportTypeId IN (SELECT
					ReportTypeId
				FROM tblReportType
				WHERE ReportTypeName IN ('Other Expenditure'))

			SELECT
				@ProductionExpenseClosingBalance = SUM(OpeningBalanceAmount) + (SUM(Debit) - SUM(Credit))
			FROM #ReportData
			WHERE ReportTypeId IN (SELECT
					ReportTypeId
				FROM tblReportType
				WHERE ReportTypeName IN ('Expenditure'))

			SET @GrossProfit =
			(ISNULL(@RevenueClosingBalance, 0) + ISNULL(@ProductionExpenseClosingBalance, 0))

			SET @NetProfit =
			@GrossProfit + ISNULL(@OtherRevenueClosingBalance, 0) + ISNULL(@OtherExpenditureClosingBalance, 0)

			-- Previous Year

			SELECT
				@RevenueClosingBalance = SUM(PreviousYearBalance)
			FROM #ReportData
			WHERE ReportTypeId IN (SELECT
					ReportTypeId
				FROM tblReportType
				WHERE ReportTypeName IN ('Revenue'))

			SELECT
				@OtherRevenueClosingBalance = SUM(PreviousYearBalance)
			FROM #ReportData
			WHERE ReportTypeId IN (SELECT
					ReportTypeId
				FROM tblReportType
				WHERE ReportTypeName IN ('Other Revenue'))

			SELECT
				@OtherExpenditureClosingBalance = SUM(PreviousYearBalance)
			FROM #ReportData
			WHERE ReportTypeId IN (SELECT
					ReportTypeId
				FROM tblReportType
				WHERE ReportTypeName IN ('Other Expenditure'))

			SELECT
				@ProductionExpenseClosingBalance = SUM(PreviousYearBalance)
			FROM #ReportData

			WHERE ReportTypeId IN (SELECT
					ReportTypeId
				FROM tblReportType
				WHERE ReportTypeName IN ('Expenditure'))

			SET @PreviousYearGrossProfit =
			(ISNULL(@RevenueClosingBalance, 0) + ISNULL(@ProductionExpenseClosingBalance, 0))
					   			 
			SET @PreviousYearNetProfit =
			@PreviousYearGrossProfit + ISNULL(@OtherRevenueClosingBalance, 0) + ISNULL(@OtherExpenditureClosingBalance, 0)

		END


		
		IF (@ReportType = 'Balance Sheet')
		BEGIN

			SELECT
				@ProfitGroup = LedgerGroupId
			FROM tblLedgerGroup
			WHERE LedgerGroupName = 'Capital Account'
			AND CompanyID = @CompanyId

			-- Current Year
			DECLARE @RevenueType INT
				   ,@OtherRevenueType INT
				   ,@OtherExpenditureType INT
				   ,@ExpenditureType INT
				   ,@PurchaseAccountsType INT

			SELECT
				@RevenueType = ReportTypeId
			FROM tblReportType
			WHERE ReportTypeName = 'Revenue'
			SELECT
				@OtherRevenueType = ReportTypeId
			FROM tblReportType
			WHERE ReportTypeName = 'Other Revenue'
			SELECT
				@OtherExpenditureType = ReportTypeId
			FROM tblReportType
			WHERE ReportTypeName = 'Other Expenditure'
			SELECT
				@ExpenditureType = ReportTypeId
			FROM tblReportType
			WHERE ReportTypeName = 'Expenditure'

			SELECT
				@PurchaseAccountsType = ReportTypeId
			FROM tblLedgerGroup
			WHERE LedgerGroupName = 'Purchase Accounts'

			SELECT
				@RevenueClosingBalance =
				SUM(OpeningBalanceAmount) + (SUM(Debit) - SUM(Credit))
				+
				(CASE
					WHEN @PurchaseAccountsType = @RevenueType THEN (@OpeningStockBalance - @ClosingStockBalance)
					ELSE 0
				END)
			FROM #ReportData
			WHERE ReportTypeId = @RevenueType


			SELECT
				@OtherRevenueClosingBalance =
				SUM(OpeningBalanceAmount) + (SUM(Debit) - SUM(Credit))
				+
				(CASE
					WHEN @PurchaseAccountsType = @OtherRevenueType THEN (@OpeningStockBalance - @ClosingStockBalance)
					ELSE 0
				END)
			FROM #ReportData

			WHERE ReportTypeId = @OtherRevenueType

			SELECT
				@OtherExpenditureClosingBalance =
				SUM(OpeningBalanceAmount) + (SUM(Debit) - SUM(Credit))
				+
				(CASE
					WHEN @PurchaseAccountsType = @OtherExpenditureType THEN (@OpeningStockBalance - @ClosingStockBalance)
					ELSE 0
				END)
			FROM #ReportData
			WHERE ReportTypeId = @OtherExpenditureType


			SELECT
				@ProductionExpenseClosingBalance =
				SUM(OpeningBalanceAmount) + (SUM(Debit) - SUM(Credit))
				+
				(CASE
					WHEN @PurchaseAccountsType = @ExpenditureType THEN (@OpeningStockBalance - @ClosingStockBalance)
					ELSE 0
				END)
			FROM #ReportData

			WHERE ReportTypeId = @ExpenditureType

			SET @GrossProfit =
			(ISNULL(@RevenueClosingBalance, 0) + ISNULL(@ProductionExpenseClosingBalance, 0))

			SET @NetProfit =
			@GrossProfit + ISNULL(@OtherRevenueClosingBalance, 0) + ISNULL(@OtherExpenditureClosingBalance, 0)
		END

		
		-- Insert Gross Profit / Loss
		IF (@ReportType = 'Profit & Loss')
		BEGIN
			INSERT INTO #ReportData
				SELECT
					-3 AS Id
					,'L' + cast(-3 as varchar(100)) as IdStr
				   ,CASE
						WHEN @GrossProfit < 0 THEN 'Gross Profit'
						ELSE 'Gross Loss'
					END AS LedgerName
				   ,NULL AS ParentId
				   ,NULL As ParentIdStr
				   ,CASE
						WHEN @GrossProfit >= 0 THEN 'Dr'
						ELSE 'Cr'
					END AS OpeningBalanceCrDr
				   ,@GrossProfit AS OpeningBalanceAmount
				   ,0 AS Debit
				   ,0 AS Credit
				   ,0 AS NetTransaction
				   ,@GrossProfit AS ClosingBalance
				   ,CASE
						WHEN @GrossProfit >= 0 THEN 'Dr'
						ELSE 'Cr'
					END AS ClosingBalanceCrDr
				   ,CAST(0 AS BIT) AS IsLedger
				   ,(SELECT
							ReportTypeSequence
						FROM tblReportType
						WHERE ReportTypeName = 'Expenditure')
					AS ReportTypeSequence
				   ,1000 AS LedgerGroupSequence
				   ,-1 AS ReportTypeId
				   ,@PreviousYearGrossProfit AS PreviousYearBalance
				   ,CASE
						WHEN @PreviousYearGrossProfit < 0 THEN 'Dr'
						ELSE 'Cr'
					END AS PreviousYearBalanceCrDr
				   ,0 AS LedgerOpeningBalance
				   ,'' AS LedgerOpeningBalanceCrDr
				   ,0 AS LedgerGroupID
				   ,0 AS CurrencyID
				   ,0 AS ClosingBalanceFc
				   ,0 AS ExRate
				   ,''
		END

		DECLARE @NetProfit1 NUMERIC(18, 2)
		-- Insert Net Profit / Loss
		IF EXISTS (SELECT
					1
				FROM tblLedgerFinanceYearOpeningBalance lfyob
				WHERE lfyob.LedgerId = -4
				AND lfyob.FinancialYearID = @CompanyFinancialYearId)
			SELECT
				@NetProfit1 = lfyob.Amount  -- AS OpeningBalanceAmount				  
			FROM tblLedgerFinanceYearOpeningBalance lfyob
			WHERE lfyob.LedgerId = -4
			AND lfyob.FinancialYearID = @CompanyFinancialYearId

		SET @NetProfit = @NetProfit + ISNULL(@NetProfit1, 0)

		INSERT INTO #ReportData
			SELECT
				-4 AS Id
				,'L' + cast(-4 as varchar(100)) as IdStr
			   ,CASE
					WHEN @NetProfit < 0 THEN 'Net Profit'
					ELSE 'Net Loss'
				END AS LedgerName
			   ,ISNULL(@ProfitGroup, 0) AS ParentId
			   ,'G' + Cast(ISNULL(@ProfitGroup, 0) as varchar(100)) As ParentIdStr
			   ,CASE
					WHEN @NetProfit >= 0 THEN 'Dr'
					ELSE 'Cr'
				END AS OpeningBalanceCrDr
			   ,@NetProfit AS OpeningBalanceAmount
			   ,0 AS Debit
			   ,0 AS Credit
			   ,0 AS NetTransaction
			   ,@NetProfit AS ClosingBalance
			   ,CASE
					WHEN @NetProfit >= 0 THEN 'Dr'
					ELSE 'Cr'
				END AS ClosingBalanceCrDr
			   ,CAST(0 AS BIT) AS IsLedger
			   ,9 AS ReportTypeSequence
			   ,0 AS LedgerGroupSequence
			   ,-1 AS ReportTypeId
			   ,@PreviousYearNetProfit AS PreviousYearBalance
			   ,CASE
					WHEN @PreviousYearNetProfit < 0 THEN 'Dr'
					ELSE 'Cr'
				END AS PreviousYearBalanceCrDr
			   ,0 AS LedgerOpeningBalance
			   ,'' AS LedgerOpeningBalanceCrDr
			   ,0 AS LedgerGroupId
			   ,0 AS CurrencyID
			   ,0 AS ClosingBalanceFc
			   ,0 AS ExRate
			   ,''
	END
	
	BEGIN -- REPORT: Grand Total

		IF (@ReportType <> 'Profit & Loss')
		BEGIN
			INSERT INTO #ReportData
				SELECT
					-2 AS Id
					,'L' + cast(-2 as varchar(100)) as IdStr
				   ,'Grand Total' AS LedgerName
				   ,NULL AS ParentId
				   ,NULL AS ParentIdStr
				   ,CASE
						WHEN SUM(OpeningBalanceAmount) > 0 THEN 'Cr'
						WHEN SUM(OpeningBalanceAmount) < 0 THEN 'Dr'
						ELSE ''
					END AS OpeningBalanceCrDr
				   ,SUM(OpeningBalanceAmount) AS OpeningBalanceAmount
				   ,SUM(Debit) AS Debit
				   ,SUM(Credit) AS Credit
				   ,SUM(Debit) - SUM(Credit) AS Nettransaction
				   ,
					-- SUM(OpeningBalanceAmount) + SUM(Debit) - SUM(Credit) AS ClosingBalance,
					SUM(ClosingBalance) AS ClosingBalance
				   ,CASE
						WHEN (SUM(OpeningBalanceAmount) + SUM(Debit) - SUM(Credit)) >= 0 THEN 'Dr'
						ELSE 'Cr'
					END AS ClosingBalanceCrDr
				   ,CAST(0 AS BIT) AS IsLedger
				   ,10 AS ReportTypeSequence
				   ,0 AS LedgerGroupSequence
				   ,-1 AS ReportTypeId
				   ,SUM(PreviousYearBalance) AS PreviousYearBalance
				   ,CASE
						WHEN SUM(PreviousYearBalance) > 0 THEN 'Cr'
						WHEN SUM(PreviousYearBalance) < 0 THEN 'Dr'
						ELSE ''
					END AS PreviousYearBalanceCrDr
				   ,SUM(LedgerOpeningBalance) AS LedgerOpeningBalance
				   ,CASE
						WHEN SUM(LedgerOpeningBalance) > 0 THEN 'Cr'
						WHEN SUM(LedgerOpeningBalance) < 0 THEN 'Dr'
						ELSE ''
					END AS LedgerOpeningBalanceCrDr
				   ,0 AS LedgerGroupID
				   ,0 AS CurrencyID
				   ,SUM(ClosingBalanceFc) AS ClosingBalanceFc
				   ,0 AS ExRate
				   ,''
				FROM #ReportData
		END

	END
	
	
	BEGIN -- Select data

		Create TABLE #Report  (Id INT, ParentId INT, ParentIdStr varchar(100), LedgerGroupName VARCHAR(100),
		   CrDr varchar(2), OpeningBalanceAmount NUMERIC(18, 2), Debit NUMERIC(18, 2), Credit NUMERIC(18, 2),
			NetTransaction NUMERIC(18, 2), ClosingBalance NUMERIC(18, 2),
		   ClosingBalanceCrDr varchar(2), PLPreviousYear NUMERIC(18, 2), PLPreviousYearCrDr varchar(2),
			BSPreviousYear numeric(18, 2), BSPreviousYearCrDr varchar(2), IsLedger BIT
		   ,CurrencyID INT, ClosingBalanceFc numeric(18, 2), ExRate numeric(18, 2),
		   ReportTypeId INT, ReportTypeSequence INT, LedgerGroupSequence INT, Ids varchar(max))

		;

		--select ParentId, * from @ReportData oRder by Id;
		--return;
	
	

		;WITH C
		AS
		(SELECT
				T.Id
				,T.IdStr
			   ,T.OpeningBalanceAmount
			   ,T.Debit
			   ,T.Credit
			   ,T.NetTransaction
			   ,T.ClosingBalance
			   ,T.PreviousYearBalance
			   ,T.LedgerOpeningBalance
			   ,T.Id AS RootID
			   ,T.IdStr AS RootIDStr
			   ,T.CurrencyID
			   ,T.ClosingBalanceFc
			   ,T.ExRate
			   ,T.IsLedger
			   --,case when T.IsLedger = 1 then 'L' else 'G' end + CAST(T.Id as varchar(max)) as Ids
			   --,case when T.IsLedger = 1 then 'L' else 'G' end + CAST(T.Id as varchar(max)) as Ids
			FROM #ReportData T
			--WHERE T.iD = 13 or T.Id = 2 or T.ParentId = 13 or T.ParentId = 2
			UNION ALL
			SELECT
				T.Id
				,T.IdStr
			   ,T.OpeningBalanceAmount
			   ,T.Debit
			   ,T.Credit
			   ,T.NetTransaction
			   ,T.ClosingBalance
			   ,T.PreviousYearBalance
			   ,T.LedgerOpeningBalance
			   ,C.RootID
			   ,C.RootIDStr
			   ,C.CurrencyID
			   ,C.ClosingBalanceFc
			   ,C.ExRate
			   ,T.IsLedger
			   --,case when T.IsLedger = 1 then 'L' else 'G' end + CAST(T.Id as varchar(max)) as Ids
			   --,cast(C.Ids + '>' + case when T.IsLedger = 1 then 'L' else 'G' end + cast(T.Id as varchar(max)) as varchar(max)) as Ids
			FROM #ReportData T
			INNER JOIN C
				ON T.ParentIdStr = C.IdStr )
			

	
	
	
	
		INSERT INTO #Report
		SELECT
			T.Id
		   ,ISNULL(T.ParentId, 0) AS ParentId
		   ,T.ParentIdStr AS ParentIdStr
		   ,T.LedgerName AS LedgerGroupName
		   ,CASE
				WHEN ISNULL(T.OpeningBalanceCrDr, '') = '' THEN CASE
						WHEN S.OpeningBalanceAmount > 0 THEN 'Dr'
						WHEN S.OpeningBalanceAmount < 0 THEN 'Cr'
						ELSE ''
					END
				ELSE T.OpeningBalanceCrDr
			END AS CrDr
		   ,ABS(ISNULL(S.OpeningBalanceAmount, 0)) AS OpeningBalanceAmount
		   ,ABS(ISNULL(S.Debit, 0)) AS Debit
		   ,ABS(ISNULL(S.Credit, 0)) AS Credit
		   ,ISNULL(S.NetTransaction, 0) NetTransaction
		   ,ABS(ISNULL(S.ClosingBalance, 0)) AS ClosingBalance
		   ,CASE
				WHEN ISNULL(T.ClosingBalanceCrDr, '') = '' THEN CASE
						WHEN S.ClosingBalance > 0 THEN 'Dr'
						WHEN S.ClosingBalance < 0 THEN 'Cr'
						ELSE ''
					END
				ELSE T.ClosingBalanceCrDr
			END AS ClosingBalanceCrDr
		   ,ABS(S.PLPreviousYear) AS PLPreviousYear
		   ,CASE
				WHEN ISNULL(T.PreviousYearBalanceCrDr, '') = '' THEN CASE
						WHEN S.PLPreviousYear > 0 THEN 'Dr'
						WHEN S.PLPreviousYear < 0 THEN 'Cr'
						ELSE ''
					END
				ELSE T.PreviousYearBalanceCrDr
			END AS PLPreviousYearCrDr
		   ,ABS(S.BSPreviousYear) AS BSPreviousYear
		   ,CASE
				WHEN S.BSPreviousYear > 0 THEN 'Dr'
				WHEN S.BSPreviousYear < 0 THEN 'Cr'
				ELSE ''
			END AS BSPreviousYearCrDr
		   ,T.IsLedger
		   ,T.CurrencyID
		   ,ABS(ISNULL(S.ClosingBalanceFc, 0)) AS ClosingBalanceFc
		   ,T.ExRate
		   ,T.ReportTypeId,
		   T.ReportTypeSequence, T.LedgerGroupSequence
		   --, T.Ids 
		   ,case when T.IsLedger = 1 then 'L' else 'G' end + cast(T.Id as varchar(max)) as Ids
		FROM #ReportData T
		INNER JOIN (SELECT
				RootIDStr

			   ,SUM(ISNULL(OpeningBalanceAmount, 0)) AS OpeningBalanceAmount
			   ,SUM(ISNULL(Debit, 0)) AS Debit
			   ,SUM(ISNULL(Credit, 0)) AS Credit
			   ,SUM(ISNULL(NetTransaction, 0)) AS NetTransaction
			   ,SUM(ISNULL(ClosingBalance, 0)) AS ClosingBalance
			   ,SUM(ISNULL(PreviousYearBalance, 0)) AS PLPreviousYear
			   ,SUM(ISNULL(LedgerOpeningBalance, 0)) AS BSPreviousYear
			   ,CurrencyID
			   ,SUM(ISNULL(ClosingBalanceFc, 0)) AS ClosingBalanceFc
			   ,ExRate
			   --,Ids
			FROM C
			GROUP BY RootIDStr
					,CurrencyID
					--,Ids
					,ExRate) AS S


			ON T.IdStr = S.RootIDStr
		WHERE T.LedgerName = 'Grand Total'

		OR (@ReportType = 'Trial Balance'
		AND (S.OpeningBalanceAmount <> 0
		OR S.Debit <> 0
		OR S.Credit <> 0))

		OR (@ReportType = 'Profit & Loss'
		AND (S.ClosingBalance <> 0
		OR S.PLPreviousYear <> 0))

		OR (@ReportType = 'Balance Sheet'
		AND (S.ClosingBalance <> 0
		OR S.BSPreviousYear <> 0))
		--AND 
		--	(T.ReportTypeId = -1 OR
		--	T.ReportTypeId IN (SELECT ReportTypeId FROM @ReportTypeTable))
		ORDER BY T.ReportTypeSequence, T.LedgerGroupSequence, T.LedgerName
	--OPTION (MAXRECURSION 0)




		IF EXISTS (SELECT * FROM #REPORT WHERE LedgerGroupName = 'Net Loss')
		BEGIN
			declare @GrossLoss NUMERIC(18, 2), @OperatingCosts NUMERIC(18, 2), 
			@BankFinancialCost NUMERIC(18, 2), @IndirectIncomes NUMERIC(18, 2)

			SELECT @GrossLoss = ClosingBalance FROM #Report WHERE LedgerGroupName = 'Gross Loss'
			SELECT @OperatingCosts = ClosingBalance FROM #Report WHERE LedgerGroupName = 'Operating Costs'
			SELECT @BankFinancialCost = ClosingBalance FROM #Report WHERE LedgerGroupName = 'Bank & Financial Costs'
			SELECT @IndirectIncomes = ClosingBalance FROM #Report WHERE LedgerGroupName = 'Indirect Incomes'

			--Commented due to Net Loss not showing in trial balance as discussed with Mr.Rao

			--UPDATE #Report 
			--SET 
			--	ClosingBalance = ISNULL(@GrossLoss, 0) + ISNULL(@OperatingCosts, 0) 
			--	+ ISNULL(@BankFinancialCost, 0) - ISNULL(@IndirectIncomes, 0)  
			--WHERE LedgerGroupName = 'Net Loss'
		END

		SELECT 
			Id, ParentId, ParentIdStr
		   ,Ids
		   ,IsLedger
		   ,rp.LedgerGroupName
		   ,CrDr
		   ,OpeningBalanceAmount
		   ,Debit
		   ,Credit
		   ,NetTransaction
		   ,ClosingBalance
		     ,case when isnull(ClosingBalance,0)=0 then '' else ClosingBalanceCrDr end ClosingBalanceCrDr
		   ,PLPreviousYear
		   ,case when isnull(PLPreviousYear,0)=0 then '' else PLPreviousYearCrDr end PLPreviousYearCrDr
		   ,BSPreviousYear
		   ,case when isnull(BSPreviousYear,0)=0 then '' else BSPreviousYearCrDr end BSPreviousYearCrDr
		   ,rp.CurrencyID
		   ,ClosingBalanceFc
		   ,ExRate
		   ,rp.ReportTypeId 
		   ,ReportTypeSequence
		   ,rp.LedgerGroupSequence
		   ,cur.Symbol CurrencySymbol
		   ,lg.LedgerGroupName MainLedgerGroupName
		FROM 
			#Report rp
			LEFT JOIN tblCurrency cur ON rp.CurrencyID=cur.CurrencyID
			LEFT JOIN tblLedgerGroup lg ON rp.Id=lg.LedgerGroupID AND rp.IsLedger=0
		ORDER BY
			ReportTypeSequence, LedgerGroupSequence, LedgerGroupName



		

	END

	
END


