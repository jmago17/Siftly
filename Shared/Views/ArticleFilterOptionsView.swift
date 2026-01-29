//
//  ArticleFilterOptionsView.swift
//  RSS RAIder
//

import SwiftUI

struct ArticleFilterOptionsView: View {
    @Binding var filters: ArticleFilterOptions

    var body: some View {
        Section {
            Picker("Coincidencia", selection: $filters.matchMode) {
                ForEach(FilterMatchMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            TextField("Contenido del articulo", text: $filters.contentQuery)
            TextField("URL del articulo", text: $filters.urlQuery)
            TextField("Titulo del feed", text: $filters.feedTitleQuery)
            TextField("Autor", text: $filters.authorQuery)

            Toggle("Fecha exacta", isOn: $filters.useExactDate)
            if filters.useExactDate {
                DatePicker("Fecha", selection: $filters.exactDate, displayedComponents: .date)
            }

            Toggle("Fecha relativa", isOn: $filters.useRelativeDate)
            if filters.useRelativeDate {
                Picker("Regla", selection: $filters.relativeComparison) {
                    ForEach(RelativeDateComparison.allCases) { comparison in
                        Text(comparison.displayName).tag(comparison)
                    }
                }

                Stepper(value: relativeValueBinding, in: 1...365, step: 1) {
                    Text("Valor: \(relativeValueBinding.wrappedValue)")
                }

                Picker("Unidad", selection: $filters.relativeUnit) {
                    ForEach(RelativeDateUnit.allCases) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
            }
        } header: {
            Text("Filtros avanzados")
        } footer: {
            Text("Usa estos filtros para refinar por contenido, URL, feed, autor o fecha. Puedes combinar las condiciones segun el modo seleccionado.")
        }
        .onChange(of: filters.useRelativeDate) { _, newValue in
            if newValue && filters.relativeValue < 1 {
                filters.relativeValue = 1
            }
        }
    }

    private var relativeValueBinding: Binding<Int> {
        Binding(
            get: { max(filters.relativeValue, 1) },
            set: { filters.relativeValue = max(1, $0) }
        )
    }
}

#Preview {
    Form {
        ArticleFilterOptionsView(filters: .constant(ArticleFilterOptions()))
    }
}
