Option Explicit

''
'' Open Excel file
''
'' Link the application to the Bloomberg API 3.5 COM type library for access to Bloomberg functionality.
''   Open the "Tools" menu and select "References...".
''   Locate and check "Bloomberg API COM 3.5 Type Library"
''   Click the OK button to complete the changes
''
'' Add 3 Buttons to the sheet.
'' On the Click event add:
''
'' Dim bbControl As New Class1
'' Sub Button1_Click()   
''    bbControl.BtcaRequest 1  '' 1 - getReportableColumns
'' End Sub
'' Sub Button2_Click()
''    bbControl.BtcaRequest 2  '' 2 - getReportableTargets
'' End Sub
'' Sub Button3_Click()
''    bbControl.BtcaRequest 3  '' 3 - btcaDataRequest
'' End Sub

'' Create an Empty Class Module and set this file content as Class1 source
''  
			
Private WithEvents sessionBtca As blpapicomLib2.session
Dim serviceBtca As blpapicomLib2.service
Dim currentRow As Long
Dim reqType As Long
Dim LogRowIdx As Long
Dim serviceName As String
Dim serverHostName As String
Dim serverPort As Long
Private Const OutColStart As Integer = 7


Private Sub Class_Initialize()
    '' Init BLPAPI
    Set sessionBtca = New blpapicomLib2.session
    Dim sessionOptions As blpapicomLib2.sessionOptions
    Set sessionOptions = sessionBtca.CreateSessionOptions
    sessionOptions.ServerHost = "localhost"
    sessionOptions.serverPort = 8194
    sessionBtca.SetSessionOptions sessionOptions
    
    sessionBtca.QueueEvents = True
    sessionBtca.Start
    sessionBtca.OpenService ("//blp/btcaapisvc")
    Set serviceBtca = sessionBtca.GetService("//blp/btcaapisvc")

End Sub

Private Sub Class_Terminate()
    Set sessionBtca = Nothing
End Sub


Private Sub LogIt(ByVal msg As String)
    On Error GoTo SomeErr
    LogRowIdx = LogRowIdx + 1
    Worksheets("Log").Cells(LogRowIdx, 1).Value = Now
    Worksheets("Log").Cells(LogRowIdx, 1).NumberFormat = "yyyy-mm-dd hh:mm:ss;@"
    Worksheets("Log").Cells(LogRowIdx, 2).Value = msg
SomeErr:
    ActiveSheet.Cells(2, OutColStart).Value = msg
    ActiveSheet.Cells(2, OutColStart).WrapText = False
End Sub

'' Prepare the BTCA request and send it
Public Sub BtcaRequest(ByVal reqType As Integer)
    LogRowIdx = 1
    ActiveSheet.Range("A1:W4000").Clear
    LogIt "Server " + serverHostName + ":" + CStr(serverPort)
    LogIt "Calling DA service " + serviceName + " ..."
 
    Dim req As REQUEST
    currentRow = 5
    '' Setup the request
    If reqType = 1 Then '' reportableColumns
        Set req = serviceBtca.CreateRequest("getReportableColumns")
        Dim trgt1 As Element
        Set trgt1 = req.GetElement("targets")
        trgt1.SetElement "systemType", "EMS"
        trgt1.SetElement "systemName", "EMS"
        trgt1.SetElement "firmOrPxNumber", "9001"
    ElseIf reqType = 2 Then  '' reportableTargets
        Set req = serviceBtca.CreateRequest("getReportableTargets")
    Else
        Set req = serviceBtca.CreateRequest("btcaDataRequest")
        req.Set "queryName", "Excel API "
        req.Set "startDate", "2020-06-20T00:00:00"
        req.Set "endDate", "2020-06-27T00:00:00"
        req.Set "calculationCurrency", "USD"
        
        Dim Cols As Element
        Set Cols = req.GetElement("columns")
        Dim Col As Element
        Set Col = Cols.AppendElment()
        Col.SetElement "columnId", "BuyOrSell"
        Set Col = Cols.AppendElment()
        Col.SetElement "columnId", "Size"
        
        Dim trgt As Element
        Set trgt = req.GetElement("targets")
        trgt.SetElement "systemType", "EMS"
        trgt.SetElement "systemName", "EMS"
        trgt.SetElement "firmOrPxNumber", "9001"
    
        Dim asset As Element
        Set asset = req.GetElement("assetTypes")
        asset.AppendValue ("Future")
        asset.AppendValue ("Equity")

    End If

    '' Send the request
    sessionBtca.SendRequest req

End Sub

'' Wait for RESPONSE event and process it
Private Sub sessionBtca_ProcessEvent(ByVal obj As Object)

    On Error GoTo errHandler

    Dim eventObj As blpapicomLib2.Event
    Set eventObj = obj
    Dim a As Integer
    Dim currentCol As Integer
    Dim b As Long
    Dim ColRowIdx As Long
    Dim RowFldIdx As Long
    Dim ccc As Element
    Dim ColRes As Boolean
    Dim DataRes As Boolean
    Dim ErrRes As Boolean
    Dim firstrow As Boolean
    Dim ColRow As Element
    Dim field As Element

    If Application.Ready Then
        If eventObj.EventType = RESPONSE Or eventObj.EventType = PARTIAL_RESPONSE Then
            LogIt "Loading Data ..."
            ActiveSheet.Cells(3, OutColStart).Value = ""
            ActiveSheet.Cells(3, OutColStart + 1).Value = ""
            Dim it As blpapicomLib2.MessageIterator
            Set it = eventObj.CreateMessageIterator()

            Do While it.Next()
                Dim msg As Message
                Set msg = it.Message
                Dim topEle As Element
                Set topEle = msg.AsElement()
                
                If topEle.Name = "errorResponse" Then  '' errorResponse
                    currentCol = OutColStart
                    Dim Errs As Element
                    Set Errs = topEle.GetElement("errors")
                    ActiveSheet.Cells(currentRow, currentCol).Value = "Errors from service:"
                    currentRow = currentRow + 1
                    For b = 0 To Errs.NumValues - 1
                        ''Set ccc = Errs.GetValue(b)
                        ActiveSheet.Cells(currentRow, currentCol).Value = Errs.GetValue(b)
                        currentRow = currentRow + 1
                    Next b
                    
                ElseIf topEle.Name = "reportableTargetsResponse" Then  '' reportableTargetsResponse
                    Dim trgts As Element
                    Set trgts = topEle.GetElement("targets")
                    firstrow = True
                    For ColRowIdx = 0 To trgts.NumValues - 1  '' For each row
                        currentCol = OutColStart
                        Set ColRow = trgts.GetValue(ColRowIdx)
                        For RowFldIdx = 0 To ColRow.NumElements - 1  '' For each field
                            Set ColRow = trgts.GetValue(ColRowIdx)
                            Set field = ColRow.GetElement(RowFldIdx)
                            If firstrow Then
                                ActiveSheet.Cells(currentRow - 1, currentCol).Value = field.Name
                                ActiveSheet.Cells(currentRow - 1, currentCol).Font.Color = vbRed
                                ActiveSheet.Cells(currentRow - 1, currentCol).Font.Bold = True
                                ActiveSheet.Cells(currentRow - 1, currentCol).Font.Underline = xlUnderlineStyleSingle
                            End If
                            ActiveSheet.Cells(currentRow, currentCol).Value = field.Value
                            currentCol = currentCol + 1
                        Next RowFldIdx
                        firstrow = False
                        currentRow = currentRow + 1
                    Next ColRowIdx
                ElseIf topEle.Name = "reportableColumnsResponse" Then  '' reportableColumnsResponse
                    Dim Cols As Element
                    Set Cols = topEle.GetElement("columns")
                    currentRow = currentRow + 1
                    firstrow = True
                    For ColRowIdx = 0 To Cols.NumValues - 1  '' For each row
                        Set ColRow = Cols.GetValue(ColRowIdx)
                        Dim fieldColId As Element
                        Set fieldColId = ColRow.GetElement("columnId")
                        currentCol = OutColStart
                        For RowFldIdx = 0 To ColRow.NumElements - 1  '' For each field
                            Set field = ColRow.GetElement(RowFldIdx)
                            If firstrow Then
                                ActiveSheet.Cells(currentRow - 1, currentCol).Value = field.Name
                                ActiveSheet.Cells(currentRow - 1, currentCol).Font.Color = vbRed
                                ActiveSheet.Cells(currentRow - 1, currentCol).Font.Bold = True
                                ActiveSheet.Cells(currentRow - 1, currentCol).Font.Underline = xlUnderlineStyleSingle
                                
                            End If
                            If field.IsArray = False Then
                                ActiveSheet.Cells(currentRow, currentCol).Value = field.Value
                            Else
                                Dim curr As Element
                                Dim str As String
                                str = ""
                                For b = 0 To field.NumValues - 1
                                    str = str & field.GetValue(b) & ","
                                Next b
                                ActiveSheet.Cells(currentRow, currentCol).Value = Left(str, Len(str) - 1)
                            End If
                            currentCol = currentCol + 1
NextField:
                        Next RowFldIdx
                        firstrow = False
                        currentRow = currentRow + 1
NextRow:
                    Next ColRowIdx
                    ActiveSheet.Cells(3, OutColStart).Value = "Loaded " + CStr(Cols.NumValues - 1) + " Columns"
                    
                ElseIf topEle.Name = "btcaDataResponse" Then '' btcaDataResponse
                   Dim resp As Element
                   Set resp = topEle.GetElement("resultId")
                   Dim DataTable As Element
                   Set DataTable = topEle.GetElement("dataTable")
                   currentCol = OutColStart
                   
                   '' Header
                   Dim headerCols As Element
                   Set headerCols = DataTable.GetElement("headerRow").GetElement("headerColumns")
                   Dim c As Integer
                   For c = 0 To headerCols.NumValues - 1
                       Dim ColTitle As Element
                       Set ColTitle = headerCols.GetValue(c).GetElement("columnTitle")
                       ActiveSheet.Cells(currentRow, currentCol + c).Font.Bold = True
                       ActiveSheet.Cells(currentRow, currentCol + c).Font.Underline = xlUnderlineStyleSingle
                       ActiveSheet.Cells(currentRow, currentCol + c).Font.Color = vbRed
                       ActiveSheet.Cells(currentRow, currentCol + c).Value = ColTitle.Value
                   Next c
                   
                   '' Data
                   currentRow = currentRow + 1
                   Dim dataRows As Element
                   Set dataRows = DataTable.GetElement("dataRows")
                   For c = 0 To dataRows.NumValues - 1
                       Dim dataRow As Element
                       Set dataRow = dataRows.GetValue(c)
                       Set Cols = dataRow.GetElement("cells")
                       currentCol = OutColStart
                       Dim d As Integer
                       For d = 0 To Cols.NumValues - 1
                            Dim Col As Element
                            Set Col = Cols.GetValue(d)
                            Dim val As Element
                            Set val = Col.GetElement(0)
                            ActiveSheet.Cells(currentRow, currentCol + d).Value = val.Value
                        Next d
                       currentRow = currentRow + 1
                   Next c
                   ActiveSheet.Cells(3, OutColStart).Value = "Loaded " & dataRows.NumValues & " Rows"
                   ActiveSheet.Cells(3, OutColStart + 1).Value = "RepId=" + resp.Value
                   
                Else
                    MsgBox "Got unknown response : "
                End If
            Loop  '' it.Next()
            LogIt "Done"
        End If  '' EventType = RESPONSE
    End If

    Exit Sub

errHandler:
    LogIt "Got error when parsing response : " & Err.Description
    MsgBox "Got error when parsing response : " & Err.Description

End Sub
