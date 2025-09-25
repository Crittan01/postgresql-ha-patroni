-- 0_value_types.sql
-- Este archivo debe ejecutarse ANTES que cualquier otro dump
-- Datos iniciales para la tabla value_types

INSERT INTO value_types (name, regex, description, author, creation_date, last_update) VALUES
('ALPHANUMERIC', 'Regex', 'Letras y números', 'omartiag', 1750386462, 1750386462),
('ALPHABETIC', 'Regex', 'Only letters and numbers', 'omartiag', 1750386462, 1750386462),
('NUMBER', 'Regex', 'Only Numbers', 'omartiag', 1750386462, 1750386462),
('BOOLEAN', 'Regex', 'False or True', 'omartiag', 1750386462, 1750386462),
('DATE', 'Regex', 'Date', 'omartiag', 1750386462, 1750386462),
('IMAGE', 'Regex', 'Image', 'omartiag', 1750386462, 1750386462),
('CONTRACT', 'Regex', 'autogenereta type contract', 'omartiag', 1750386462, 1750386462),
('CASE', 'Regex', 'autogenerate type case', 'omartiag', 1750386462, 1750386462);
-- Fin de 0_value_types.sql