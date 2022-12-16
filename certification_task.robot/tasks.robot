*** Settings ***
Documentation       Template robot main suite.
...                 Orders robots from RobotSpareBin Industries Inc.
...                 Saves the order HTML receipt as a PDF file.
...                 Saves the screenshot of the ordered robot.
...                 Embeds the screenshot of the robot to the PDF receipt.
...                 Creates ZIP archive of the receipts and the images.
...                 Download an Excel file and read the rows.

Library             RPA.Browser.Selenium
Library             RPA.Excel.Files
Library             RPA.HTTP
Library             RPA.JSON
Library             RPA.Tables
Library             Collections
Library             RPA.Robocorp.WorkItems
Library             OperatingSystem
Library             RPA.Robocloud.Secrets
Library             RPA.RobotLogListener
Library             RPA.PDF
Library             RPA.Archive


*** Variables ***
${URL}=                 https://robotsparebinindustries.com/#/robot-order
${order_file}                 https://robotsparebinindustries.com/orders.csv
${robot_image_folder}                       ${CURDIR}${/}image_files
${robot_image_folder}    ${CURDIR}${/}/orders.csv
${pdf_folder}                       ${CURDIR}${/}pdf_files
${zip_file}                         ${output_folder}${/}pdf_archive.zip
${output_folder}                    ${CURDIR}${/}output
${orders_csv_file}       ${CURDIR}${/}/orders.csv


${robot_head_select}                   xpath=//select[@id='head']
${robot_groups_select}                body
${legs_number}                       xpath=//input[@placeholder="Enter the part number for the legs"]
${order_address}                    xpath=//input[@id='address']
${btn_order}                        xpath=//button[@id='order']
${order_preview}                      xpath=//button[@id='preview']
${robot_image_preview}                      xpath=//div[@id='robot-preview-image']
${Click_yes}                       xpath=//button[contains(text(), 'OK')]
${robot_detail_receipt}                      xpath=//div[@id='receipt']
${robot_orderid_element}              xpath=//p[@class='badge badge-success']
${order_next_robot}          xpath=//*[@id="order-another"]

${order_number_test_data}
${head_test_data}
${body_test_data}
${legs_test_data}
${address_test_data}


*** Tasks ***
Order robots from RobotSpareBin Industries Inc
    Open the robot order website


*** Keywords ***
Open the robot order website
    Directory Cleanup
    #Get Login Details From Vault
    open robot order website
    Open Available Browser    ${URL}
    ${orders}    Get orders
    FOR    ${_row}    IN    @{orders}
        Close the annoying modal
        Robot Order Form completing    ${row}
        View Ordered robot
        Robot Order Submit
        ${pdf}=    Store the receipt as a PDF file    ${row}[Order number]
        ${screenshot}=    Ordered Robot screenshot take    ${row}[Order number]
        Robot preview screenshot added in the receipt PDF file    ${screenshot}    ${pdf}
        Order next robot
    END


Directory Cleanup
    Log To console    Cleaning up content from previous test runs
    Create Directory    ${robot_image_folder}
    Create Directory    ${pdf_folder}

    Empty Directory    ${robot_image_folder}
    Empty Directory    ${pdf_folder}

Get Login Details From Vault
    Log To Console    Getting Secret from our Vault
    ${login_credentials}=    Get Secret    credential

Open robot order website
    Open Available Browser    ${URL}
    Maximize Browser Window
    Sleep    2s
Get orders
    RPA.HTTP.Download    url=${order_file}    target_file=${orders_csv_file}
    ${orders_table}=    Read table from CSV    path=${orders_csv_file}
    Log To Console    Orders data ${orders_table}
    RETURN    ${orders_table}
Close the annoying modal
    Click Button    //button[normalize-space()='OK']
    Sleep    2s

Robot Order Form completing
    [Arguments]    ${row}
    ${order_number_test_data}=    Set variable    ${row}[Order number]
    ${head_test_data}=    Set variable    ${row}[Head]
    ${body_test_data}=    Set variable    ${row}[Body]
    ${legs_test_data}=    Set variable    ${row}[Legs]
    ${address_test_data}=    Set variable    ${row}[Address]
    Set Local Variable    ${radio_group_body}    xpath=//*[@id='id-body-${${body_test_data}}']

    Click Element If Visible    ${robot_head_select}
    Sleep    2s
    Select From List By Value    ${robot_head_select}    ${head_test_data}
    Select Radio Button    ${robot_groups_select}    ${body_test_data}
    Input Text When Element Is Visible    ${legs_number}    ${legs_test_data}
    Input Text When Element Is Visible    ${order_address}    ${address_test_data}
    
View Ordered robot 
    Scroll Element Into View    ${order_preview}
    Is Element Visible    ${order_preview}
    Click Button    ${order_preview}
    Is Element Visible    ${robot_image_preview}

Robot Order Submit
    Is Element Visible    ${btn_order}
    Click Button    ${btn_order}
    Sleep    3s
    #Wait Until Element Contains    //div[@id='receipt']/h3    Receipt
    Is Element Visible    ${robot_detail_receipt}

Store the receipt as a PDF file
    [Arguments]    ${ORDER_NUMBER}
    Log To Console    Order Number for processing ${ORDER_NUMBER}
    Sleep    5s
    ${order_receipt_html}=    Get Text    ${robot_detail_receipt}
    Log To Console    Receipt number ${order_receipt_html}

    Set Local Variable    ${fully_qualified_pdf_filename}    ${pdf_folder}${/}${ORDER_NUMBER}.pdf

    Html To Pdf    content=${order_receipt_html}    output_path=${fully_qualified_pdf_filename}
    RETURN    ${fully_qualified_pdf_filename}

Ordered Robot screenshot take
    [Arguments]    ${ORDER_NUMBER}

    Is Element Visible    ${robot_image_preview}    visible
    Is Element Visible    ${robot_orderid_element}    visible

    # Get the order ID
    ${orderid}=    Get Text    ${robot_orderid_element}
    Log To Console    orderid    ${orderid}
    Log To Console    img_folder ${robot_image_folder}
    # Take Snapshot & Create the File Name
    Set Local Variable    ${fully_qualified_img_filename}    ${robot_image_folder}${/}${orderid}.png
    Capture Element Screenshot    ${robot_image_preview}    ${fully_qualified_img_filename}   
    Log To Console    fully_qualified_img_filename ${fully_qualified_img_filename}

    Sleep    1sec

    Log To Console    Capturing Screenshot to ${fully_qualified_img_filename}
    RPA.Browser.Selenium.Capture Element Screenshot    ${robot_image_preview}    ${fully_qualified_img_filename}

    #RETURN    ${orderid}    ${fully_qualified_img_filename}
    RETURN    ${fully_qualified_img_filename}

Robot preview screenshot added in the receipt PDF file
    [Arguments]    ${IMG_FILE}    ${PDF_FILE}
    TRY
        Log To Console    Printing Embedding image: ${IMG_FILE}
        Log To Console    In pdf file: ${PDF_FILE}
        # Open PDF    ${PDF_FILE}
        @{myfiles}=    Create List    ${IMG_FILE}
        Add Files To PDF    ${myfiles}    ${PDF_FILE}    ${True}
        # Close PDF    ${PDF_FILE}
    EXCEPT    message
        Log To Console    message
    END

Order next robot
    # Define local variables for the UI elements
    Click Button    ${order_next_robot}

Create a ZIP file of the receipts
    Archive Folder With Zip    ${pdf_folder}    ${zip_file}    recursive=True    include=*.pdf