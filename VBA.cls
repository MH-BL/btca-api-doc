VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
END
Attribute VB_Name = "DataControl"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
Option Explicit

Private WithEvents sessionBtca As blpapicomLib2.session
Attribute sessionBtca.VB_VarHelpID = -1
Dim serviceBtca As blpapicomLib2.Service
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
    Session_Start
    
End Sub

Public Sub Session_Start()
    Dim sessionOptions As blpapicomLib2.sessionOptions
    Set sessionOptions = sessionBtca.CreateSessionOptions
    serverHostName = "localhost"
    serverPort = 8194
    serviceName = "//blp/btcaapisvc"

    sessionOptions.ServerHost = serverHostName
    sessionOptions.serverPort = serverPort
    sessionBtca.SetSessionOptions sessionOptions
    
    sessionBtca.QueueEvents = True
    sessionBtca.Start
    sessionBtca.OpenService (serviceName)
    Set serviceBtca = sessionBtca.GetService(serviceName)

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
    '' Worksheets("Log").Cells(LogRowIdx, 2).WrapText = False
SomeErr:
    Sheet1.Cells(2, OutColStart).Value = msg
    Sheet1.Cells(2, OutColStart).WrapText = False
End Sub


Public Sub BtcaRequest(ByVal reqId As Integer, ByRef sColsList() As String)
    LogRowIdx = 1
    Worksheets("Log").Range("A1:B10000").Clear
    LogIt "Server " + serverHostName + ":" + CStr(serverPort)
    LogIt "Calling DA service " + serviceName + " ..."
 
	Dim req As REQUEST
    reqType = reqId
    currentRow = 5
    '' Setup the request
    If reqType = 0 Then '' reportableColumns
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
        req.Set "startDate", "2018-01-01T00:00:00"
        req.Set "endDate", "2018-01-02T00:00:00"
        req.Set "calculationCurrency", "USD"
        
        Dim Cols As Element
        Set Cols = req.GetElement("columns")
        Dim nCol As Long
        For nCol = LBound(sColsList, 1) To UBound(sColsList, 1)
            Dim Col As Element
            Set Col = Cols.AppendElment()
            Col.SetElement "columnId", sColsList(nCol)
        Next nCol
        
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
            Sheet1.Cells(3, OutColStart).Value = ""
            Sheet1.Cells(3, OutColStart + 1).Value = ""
            Dim it As blpapicomLib2.MessageIterator
            Set it = eventObj.CreateMessageIterator()

            Do While it.Next()
                Dim msg As Message
                Set msg = it.Message
                Dim topEle As Element
                Set topEle = msg.AsElement()
                ''ccc = Msg.AsElement.Elements(0)
                ''ColRes = msg.AsElement.HasElement("reportableColumnsResponse")
                ''DataRes = msg.AsElement.HasElement("btcaDataResponse")
                ''ErrRes = msg.AsElement.HasElement("errorResponse")
                
                If topEle.Name = "errorResponse" Then  '' errorResponse
                    currentCol = OutColStart
                    Dim Errs As Element
                    '' Set Errs = Msg.GetElement("errorResponse").GetElement("errors")
                    Set Errs = topEle.GetElement("errors")
                    Sheet1.Cells(currentRow, currentCol).Value = "Errors from service:"
                    currentRow = currentRow + 1
                    For b = 0 To Errs.NumValues - 1
                        ''Set ccc = Errs.GetValue(b)
                        Sheet1.Cells(currentRow, currentCol).Value = Errs.GetValue(b)
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
                                Sheet1.Cells(currentRow - 1, currentCol).Value = field.Name
                                Sheet1.Cells(currentRow - 1, currentCol).Font.Color = vbRed
                                Sheet1.Cells(currentRow - 1, currentCol).Font.Bold = True
                                Sheet1.Cells(currentRow - 1, currentCol).Font.Underline = xlUnderlineStyleSingle
                            End If
                            Sheet1.Cells(currentRow, currentCol).Value = field.Value
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
                        '' check if to display the row
                        If Not ColGrp And Not IsEmpty(Worksheets("Config").Range("A2")) _
                           And (Worksheets("Config").Range("M2").Value <> "All") _
                           And (Application.WorksheetFunction.CountIf(Worksheets("Config").Range("$A:$A"), fieldColId.Value) = 0) Then
                            GoTo NextRow:
                        End If
                        currentCol = OutColStart
                        If ActiveSheet.Name = "Columns" Then
                            currentCol = 1
                        End If
                        For RowFldIdx = 0 To ColRow.NumElements - 1  '' For each field
                            Set field = ColRow.GetElement(RowFldIdx)
                            '' check if to display the field
                            If Not IsEmpty(Worksheets("Config").Range("J2")) _
                               And (Worksheets("Config").Range("J2").Value <> "All") _
                               And (Application.WorksheetFunction.CountIf(Worksheets("Config").Range("$J:$J"), field.Name) = 0) Then
                                GoTo NextField:
                            End If

                            If firstrow Then
                                ActiveSheet.Cells(currentRow - 1, currentCol).Value = field.Name
                                ActiveSheet.Cells(currentRow - 1, currentCol).Font.Color = vbRed
                                ActiveSheet.Cells(currentRow - 1, currentCol).Font.Bold = True
                                ActiveSheet.Cells(currentRow - 1, currentCol).Font.Underline = xlUnderlineStyleSingle
                            End If
                            If field.IsArray = False Then
                                ActiveSheet.Cells(currentRow, currentCol).Value = field.Value
                                If ColGrp And field.Name = "columnId" _
                                   And Application.WorksheetFunction.CountIf(Worksheets("Config").Range("$A:$A"), fieldColId.Value) > 0 Then
                                    ActiveSheet.Cells(currentRow, currentCol).Font.Color = vbBlue
                                End If
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
                    Sheet1.Cells(3, OutColStart).Value = "Loaded " + CStr(Cols.NumValues - 1) + " Columns"
                    
                ElseIf topEle.Name = "btcaDataResponse" Then '' btcaDataResponse
                   Dim resp As Element
                   ''Set resp = Msg.GetElement("btcaDataResponse").GetElement("resultId")
                   Set resp = topEle.GetElement("resultId")
                   Dim DataTable As Element
                   ''Set DataTable = Msg.GetElement("btcaDataResponse").GetElement("dataTable")
                   Set DataTable = topEle.GetElement("dataTable")
                   currentCol = OutColStart
                   
                   '' Header
                   Dim headerCols As Element
                   Set headerCols = DataTable.GetElement("headerRow").GetElement("headerColumns")
                   Dim c As Integer
                   For c = 0 To headerCols.NumValues - 1
                       Dim ColTitle As Element
                       Set ColTitle = headerCols.GetValue(c).GetElement("columnTitle")
                       Sheet1.Cells(currentRow, currentCol + c).Font.Bold = True
                       Sheet1.Cells(currentRow, currentCol + c).Font.Underline = xlUnderlineStyleSingle
                       Sheet1.Cells(currentRow, currentCol + c).Font.Color = vbRed
                       Sheet1.Cells(currentRow, currentCol + c).Value = ColTitle.Value
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
                            Sheet1.Cells(currentRow, currentCol + d).Value = val.Value
                        Next d
                       currentRow = currentRow + 1
                   Next c
                   Sheet1.Cells(3, OutColStart).Value = "Loaded " & dataRows.NumValues & " Rows"
                   Sheet1.Cells(3, OutColStart + 1).Value = "RepId=" + resp.Value
                   
                Else
                    MsgBox "Got unknown response : "
                End If
            Loop  '' it.Next()
            LogIt "Done"
        End If  '' EventType = RESPONSE
    End If

    Exit Sub

errHandler:
    LogIt "Got error when parsing response : " & err.Description
    MsgBox "Got error when parsing response : " & err.Description

End Sub


