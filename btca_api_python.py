from __future__ import print_function
from __future__ import absolute_import

import blpapi
import datetime
from prettytable import PrettyTable #Can be downloaded from https://pypi.org/project/prettytable/


def printBtcaResponse(msg):
    responseName = msg.asElement().name()
    response = msg.asElement()
    if responseName == "errorResponse":
        print("errors: ")
        for err in response.getElement("errors").values():
            print(err)
    elif responseName == "btcaDataResponse":
        newHdr = []
        for col in response.getElement("dataTable").getElement("headerRow").getElement("headerColumns").values():
            newHdr.append(col.getElementAsString("columnTitle"))
        tbl = PrettyTable(newHdr)
        i = 0
        for row in response.getElement("dataTable").getElement("dataRows").values():
            newRow = []
            i = i + 1
            for col in row.getElement("cells").values():
                # for col in row.getElement("columns").values():
                newRow.append(col.getElement(0).getValueAsString())
            tbl.add_row(newRow)
            #if i > 50:
            #    break
        print(tbl)
    elif responseName == "reportableColumnsResponse":
        newHdr = ['columnId', 'groupName', 'defaultDescription', 'isBenchmark']
        tbl = PrettyTable(newHdr)
        tbl.align = 'l'
        i = 0
        for col in response.getElement("columns").values():
            newRow = []
            i = i + 1
            for colId in newHdr:
                newRow.append(col.getElement(colId).getValueAsString())
            tbl.add_row(newRow)
            #if i > 50:
            #   break
         print(tbl)
    elif responseName == "reportableTargetsResponse":
        print(response)


def main():
    # Connection params
    sessionOptions = blpapi.SessionOptions()
    sessionOptions.setServerHost('localhost')
    sessionOptions.setServerPort(8194)

    # Start a Session
    session = blpapi.Session(sessionOptions)
    session.start()
    # Open btcaapisvc service
    session.openService("//blp/btcaapisvc")
    btcaService = session.getService("//blp/btcaapisvc")

    # Build request
    reqType = 2 #change to your desired request
    if (reqType == 1):
        request = btcaService.createRequest("getReportableTargets")
    if (reqType == 2):
        request = btcaService.createRequest("getReportableColumns")
    if (reqType == 3):
        request = btcaService.createRequest("btcaDataRequest")
        # request.getElement("securities").appendValue("IBM US Equity")
        request.set("queryName", "client py")
        request.set("startDate", datetime.datetime(2020, 06, 10, 0, 0, 0, 0)) # 2018-Jan-01
        request.set("endDate", datetime.datetime(2020, 06, 11, 0, 0, 0, 0))  # 2018-Jan-30
        request.set("calculationCurrency", "USD")
        col = request.getElement("columns").appendElement()
        col.setElement('columnId', 'BuyOrSell')
        col = request.getElement("columns").appendElement()
        col.setElement('columnId', 'Size')

        trgt = request.getElement('targets')
        trgt.setElement('systemType', 'EMS')    #change to your firm
        trgt.setElement('systemName', 'EMS')    #change to your firm
        trgt.setElement('firmOrPxNumber', 9001) #change to your firm

        asset = request.getElement("assetTypes")
        asset.appendValue("Equity")

        filters = request.getElement("filters")
        filter = filters.appendElement()
        filter.setElement('isExclude', 'false')
        filter.setElement("columnId", 'BuyOrSell') #Side
        filterVal = filter.getElement("filterValues")
        strsVal = filterVal.setChoice("stringValues")
        strVal = strsVal.getElement("strings")
        strVal.appendValue('B') # get only BUY orders

    # Send the request
    session.sendRequest(request)

    print("Processing Events ...")
    try:
        # Process received events
        while (True):
            # We provide timeout to give the chance to Ctrl+C handling:
            ev = session.nextEvent(500)
            #print(ev.eventType())  # debug
            for msg in ev:
                if ev.eventType() == blpapi.Event.RESPONSE or ev.eventType() == blpapi.Event.PARTIAL_RESPONSE:
                    printBtcaResponse(msg)
                else:
                    print(msg)  # debug
            # Response completly received, so we could exit
            if ev.eventType() == blpapi.Event.RESPONSE:
                break
    finally:
        # Stop the session
        session.stop()


if __name__ == "__main__":
    print("Starting ....")
    try:
        main()
    except KeyboardInterrupt:
        print("Ctrl+C pressed. Stopping...")
