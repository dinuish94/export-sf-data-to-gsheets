import ballerina/http;
import ballerina/config;
import wso2/sfdc46;
import wso2/gsheets4;

sfdc46:SalesforceConfiguration sfConfig = {
    baseUrl: config:getAsString("SF_BASE_URL"),
    clientConfig: {
        accessToken: config:getAsString("SF_ACCESS_TOKEN"),
        refreshConfig: {
            clientId: config:getAsString("SF_CLIENT_ID"),
            clientSecret: config:getAsString("SF_CLIENT_SECRET"),
            refreshToken: config:getAsString("SF_REFRESH_TOKEN"),
            refreshUrl: config:getAsString("SF_REFRESH_URL")
        }
    }
};

gsheets4:SpreadsheetConfiguration spreadsheetConfig = {
    oAuthClientConfig: {
        accessToken: config:getAsString("GS_ACCESS_TOKEN"),
        refreshConfig: {
            clientId: config:getAsString("GS_CLIENT_ID"),
            clientSecret: config:getAsString("GS_CLIENT_SECRET"),
            refreshUrl: gsheets4:REFRESH_URL,
            refreshToken: config:getAsString("GS_REFRESH_TOKEN")
        }
    }
};

@http:ServiceConfig {
    basePath:"/"
}
service opportunitiesService on new http:Listener(8080) {
    @http:ResourceConfig {
        path:"/opportunity",
        methods: ["GET"]
    }
    resource function exportOpportunities(http:Caller caller, http:Request request) returns error?{
        http:Response response = new();

        sfdc46:Client sfClient = new(sfConfig);
        gsheets4:Client gsClient = new(spreadsheetConfig);
        
        string sfQuery = "SELECT Id, Name, Account.Name from Opportunity";
        var sfResponse = sfClient->getQueryResult(sfQuery);

        if (sfResponse is sfdc46:SoqlResult){
            json sfJsonResponse = check json.constructFrom(sfResponse);
            json[] sfRecords = <json[]> sfJsonResponse.records;

            string spreadsheetId = config:getAsString("SPREADSHEET_ID");
            string sheetName = config:getAsString("SHEET_NAME");

            var spreadsheet = gsClient->openSpreadsheetById(spreadsheetId);

            if (spreadsheet is gsheets4:Spreadsheet){
                string[][] opportunities = [[]];
                opportunities[0] = ["Opportunity ID", "Opportunity Name", "Account"];
                int i = 1;

                foreach json item in sfRecords {
                    opportunities[i] = [item.Id.toString(), item.Name.toString(), item.Account.Name.toString()];
                    i = i+1;
                }

                var gsResponse = gsClient->setSheetValues(spreadsheetId, sheetName, opportunities, "A1", "C1000");

                if (gsResponse is boolean && gsResponse){
                    response.setTextPayload("Data Exported Successfully!");
                } else {
                    response.setTextPayload("Failed to Export Data!");
                }
            }
        } else {
            response.setTextPayload("Failed to Export Data!");
        }
        
        var result = caller->respond(response);
    }
}