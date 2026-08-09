<?php
/**
 * Uzbek (latin) translations for Yii core framework messages (validators, etc.).
 * Keys are the exact English source strings Yii uses in yii\validators\* and
 * related components. Only user-facing validation messages are translated here.
 */
return [
    // Required / general
    '{attribute} cannot be blank.' => '{attribute} bo\'sh bo\'lishi mumkin emas.',
    '{attribute} is invalid.' => '{attribute} noto\'g\'ri.',
    'The format of {attribute} is invalid.' => '{attribute} formati noto\'g\'ri.',
    '{attribute} should be an array.' => '{attribute} massiv bo\'lishi kerak.',
    '{attribute} must not be blank.' => '{attribute} bo\'sh bo\'lmasligi kerak.',

    // Types
    '{attribute} must be a string.' => '{attribute} matn bo\'lishi kerak.',
    '{attribute} must be an integer.' => '{attribute} butun son bo\'lishi kerak.',
    '{attribute} must be a number.' => '{attribute} son bo\'lishi kerak.',
    '{attribute} must be either "{true}" or "{false}".' => '{attribute} "{true}" yoki "{false}" bo\'lishi kerak.',
    '{attribute} must be a valid email address.' => '{attribute} yaroqli e-pochta manzili bo\'lishi kerak.',
    '{attribute} is not a valid URL.' => '{attribute} yaroqli URL emas.',

    // Uniqueness / existence
    '{attribute} "{value}" has already been taken.' => '{attribute} "{value}" allaqachon band.',

    // String length
    '{attribute} should contain at most {max, number} {max, plural, one{character} other{characters}}.' => '{attribute} ko\'pi bilan {max, number} ta belgidan iborat bo\'lishi kerak.',
    '{attribute} should contain at least {min, number} {min, plural, one{character} other{characters}}.' => '{attribute} kamida {min, number} ta belgidan iborat bo\'lishi kerak.',
    '{attribute} should contain {length, number} {length, plural, one{character} other{characters}}.' => '{attribute} {length, number} ta belgidan iborat bo\'lishi kerak.',

    // Date
    '{attribute} is not a valid date.' => '{attribute} yaroqli sana emas.',
    '{attribute} is not a valid time.' => '{attribute} yaroqli vaqt emas.',

    // Number range
    '{attribute} must be no greater than {max}.' => '{attribute} {max} dan katta bo\'lmasligi kerak.',
    '{attribute} must be no less than {min}.' => '{attribute} {min} dan kichik bo\'lmasligi kerak.',
    '{attribute} must be greater than {compareValueOrAttribute}.' => '{attribute} {compareValueOrAttribute} dan katta bo\'lishi kerak.',
    '{attribute} must be less than {compareValueOrAttribute}.' => '{attribute} {compareValueOrAttribute} dan kichik bo\'lishi kerak.',
    '{attribute} must be equal to {compareValueOrAttribute}.' => '{attribute} {compareValueOrAttribute} ga teng bo\'lishi kerak.',
    '{attribute} must not be equal to {compareValueOrAttribute}.' => '{attribute} {compareValueOrAttribute} ga teng bo\'lmasligi kerak.',

    // In-range / list
    '{attribute} is not in the list of acceptable values.' => '{attribute} qabul qilinadigan qiymatlar ro\'yxatida yo\'q.',

    // Numeric length (integer/number range on string length)
    '{attribute} should contain at most {max, number} {max, plural, one{item} other{items}}.' => '{attribute} ko\'pi bilan {max, number} ta elementdan iborat bo\'lishi kerak.',
    '{attribute} should contain at least {min, number} {min, plural, one{item} other{items}}.' => '{attribute} kamida {min, number} ta elementdan iborat bo\'lishi kerak.',

    // File / image (in case used later)
    'File upload failed.' => 'Fayl yuklashda xatolik yuz berdi.',
    'Only files with these extensions are allowed: {extensions}.' => 'Faqat quyidagi kengaytmali fayllarga ruxsat beriladi: {extensions}.',
    'Please upload a file.' => 'Iltimos, fayl yuklang.',
];
