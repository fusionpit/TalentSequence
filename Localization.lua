local _, ts = ...

local GetLocale = GetLocale

local localeText = {
    enUS = {
        TOGGLE = "Toggle Talent Sequence Window",
        LOAD = "Load",
        IMPORT = "Import",
        LOAD_TOOLTIP = "Click to Load Sequence List",
        IMPORT_TOOLTIP = "Click to Import a New Sequence",
        IMPORT_DIALOG = "Paste your talent string into the box below.",
        EARLY_LINK = "It seems the name you entered may be a link. It may not appear properly as the name for the import and overlap other elements.",
        TRY_AGAIN = "Try again",
        CONFIRM = "Continue",
        RE_ENTER = "Re-enter",
        OK = "OK",
        CANCEL = "Cancel",
        SUCCESS = "Talent import for another class successful.",
        LOAD_SEQUENCE_TIP = "Click to Load Sequence",
        NO_WOWHEAD_CLASSIC = "Sorry, the entered text doesn't appear to be a link from Wowhead's Classic Talent Calculator. Copy the url below to create one in your browser.",
        INVALID_LINK = "Sorry, the link appears to be invalid. Please make sure you've expanded the Talent Order panel and copied the entire Wowhead Talent Calculator URL or get one by copying the link below.",
        DELETE_TIP = "<Shift>-Click to Delete",
        RENAME_TIP = "Click to Rename",
        UNNAMED = "Auto-Imported from Active",
        IMPORT_NAME_DIALOG = "Enter a name for your talent build.",
        MISSING_NAME = "Please enter a name."
    },
    ruRU = {
        -- Translator ZamestoTV
        TOGGLE = "Переключить окно последовательности талантов",
        LOAD = "Загрузить",
        IMPORT = "Импорт",
        LOAD_TOOLTIP = "Кликните для загрузки списка последовательностей",
        IMPORT_TOOLTIP = "Кликните для импорта новой последовательности",
        IMPORT_DIALOG = "Вставьте строку талантов в поле ниже.",
        EARLY_LINK = "Похоже, введённое имя может быть ссылкой. Оно может некорректно отображаться как название импорта и перекрывать другие элементы.",
        TRY_AGAIN = "Попробовать снова",
        CONFIRM = "Продолжить",
        RE_ENTER = "Ввести заново",
        OK = "ОК",
        CANCEL = "Отмена",
        SUCCESS = "Импорт талантов для другого класса прошёл успешно.",
        LOAD_SEQUENCE_TIP = "Кликните для загрузки последовательности",
        NO_WOWHEAD_CLASSIC = "Извините, введённый текст не похож на ссылку из классического калькулятора талантов Wowhead. Скопируйте URL ниже, чтобы создать её в браузере.",
        INVALID_LINK = "Извините, ссылка кажется недействительной. Убедитесь, что вы раскрыли панель Порядок талантов и скопировали полный URL калькулятора талантов Wowhead, или получите её, скопировав ссылку ниже.",
        DELETE_TIP = "<Shift>-клик для удаления",
        RENAME_TIP = "Кликните для переименования",
        UNNAMED = "Автоимпорт из активных",
        IMPORT_NAME_DIALOG = "Введите название для вашего билда талантов.",
        MISSING_NAME = "Пожалуйста, введите название."
    }
};

ts.L = localeText["enUS"]
local locale = GetLocale()
if (locale == "enUS" or locale == "enGB" or localeText[locale] == nil) then
    return
end
for k, v in pairs(localeText[locale]) do
    ts.L[k] = v
end
